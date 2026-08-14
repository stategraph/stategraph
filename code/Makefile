.PHONY: all terrat
.PHONY: terrat_oss terrat_ee terrat_code_indexer ttm iris
.PHONY: test-terrat
.PHONY: generate-api-types check-api-types
.PHONY: clean

# Dune lives at the repo root so packages can reach ../../../api_schemas/
# (via ppx_blob). All commands here delegate to dune, invoked from the
# parent directory.
# Profile selection is centralised: dune-workspace pins `(profile release)`
# as the default.
# No target here passes --profile explicitly.
DUNE := dune
ROOT := $(CURDIR)/..

all: terrat

# Aggregate: build every server binary + the UI in a single dune invocation
# (the @code/terrat alias is defined in code/dune). One invocation matters
# because dune holds a workspace lock — listing the sub-targets as make
# prerequisites would let `make -j` launch parallel dune calls that block on
# each other.
terrat:
	cd $(ROOT) && $(DUNE) build @code/terrat

# Per-binary targets, useful for narrowing dev iteration to one server.
terrat_oss:
	cd $(ROOT) && $(DUNE) build code/src/terrat_oss/terrat_oss.exe

terrat_ee:
	cd $(ROOT) && $(DUNE) build code/src/terrat_ee/terrat_ee.exe

terrat_code_indexer:
	cd $(ROOT) && $(DUNE) build code/src/terrat_code_indexer/terrat_code_indexer.exe

ttm:
	cd $(ROOT) && $(DUNE) build code/src/ttm/ttm.exe

# UI assets (iris). Built last so backend dev iteration is fast.
iris:
	cd $(ROOT) && $(DUNE) build @code/src/iris/all

# Unit tests. TERRAT_TEST_DIRS defaults to the whole code/tests/ tree; a
# superset build (the monorepo) overrides it with a curated subset that
# excludes suites that repo does not build here (see Makefile.stategraph.inc).
TERRAT_TEST_DIRS := code/tests

test-terrat:
	cd $(ROOT) && $(DUNE) runtest $(TERRAT_TEST_DIRS)

# Code generation lives entirely in dune. Each generated library carries, next
# to its `(library)`: a `(rule (mode (promote (into .))) (targets (dir gen)) ...)`
# that runs the generator, formats the output with ocamlformat and promotes it
# into the library directory; a `(rule (mode (promote (into ../../../api_schemas/...))))`
# that normalises its input schema in place with `jq -S`, driven by
# `dune build @code/generate-api-types`; and a
# `<lib>.generate-api-types-pairs` rule declaring its `(input schema, destination
# dir)` pair. code/dune aggregates those pairs into `codegen-manifest`, so the
# set of generated libraries is never hand-listed here -- adding a library to
# the mechanism is purely a matter of editing its own dune file.
#
# This target just clears the previous output and dune directory target per pair
# (promote-into does not delete files the generator no longer produces, and
# dropping the target forces dune to re-run the promote rule on a warm tree),
# then asks dune to regenerate + re-normalise everything via the alias in a
# single invocation -- concurrent dune processes abort on dune's global build
# lock, so a per-pair loop under -j would race.
CODEGEN_MANIFEST := $(ROOT)/_build/default/code/codegen-manifest

generate-api-types:
	cd $(ROOT) && $(DUNE) build code/codegen-manifest
	@while read input dest; do \
	  echo "regenerating $$dest from $$input"; \
	  rm -f "$(ROOT)/$$dest"/*.ml "$(ROOT)/$$dest"/*.sql; \
	  rm -rf "$(ROOT)/_build/default/$$dest/gen"; \
	done < $(CODEGEN_MANIFEST)
	cd $(ROOT) && $(DUNE) build @code/generate-api-types

# OCaml counterpart of the frontend's `npm run check-api-types`: regenerate
# every dune-managed codegen target and fail if the committed output (or a
# normalised input schema) drifts.
check-api-types: generate-api-types
	cd $(ROOT) && git diff --exit-code -- api_schemas $$(awk '{ print $$2 }' $(CODEGEN_MANIFEST)) || { \
	  echo 'ERROR: generated files are out of sync with the schemas in api_schemas/.'; \
	  echo 'Run `make -C code check-api-types` and commit the updated api_schemas/ + generated dirs.'; \
	  exit 1; \
	}

clean:
	cd $(ROOT) && $(DUNE) clean

include stategraph.mk
