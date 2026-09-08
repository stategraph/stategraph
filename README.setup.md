## Installation

This project uses [opam](https://opam.ocaml.org/) and [dune](https://dune.build/). If these
instructions go stale, [docker/terrat/Dockerfile](./docker/terrat/Dockerfile) is the canonical
reference — its `build-base` stage runs the same setup and is exercised by CI on every push.

Create a local opam switch from the repository's root:

```shell
opam switch create -y 5.5.1 --no-depexts
eval $(opam env)
```

Add the local `opam/` directory as an opam repository (it carries terrateam-specific packages
that aren't in the default opam-repository):

```shell
opam repository add tt-opam-acsl opam
```

Pin the vendored packages so the install below picks them up from `vendor/` rather than
the upstream opam-repository:

```shell
opam pin add -n ISO8601 vendor/ISO8601 --no-depexts
opam pin add -n cohttp vendor/cohttp --no-depexts
```

Install dune and menhir, then everything pinned in `code/opam.pins`:

```shell
opam install -j$(nproc --all) -y --no-depexts dune.3.24.2 menhir
xargs -a code/opam.pins opam install -j$(nproc --all) -y --no-depexts
```

For an IDE-friendly setup, also install the LSP server and formatter:

```shell
opam install -y ocaml-lsp-server.1.27.0 ocamlformat.0.29.0
```

You can now build:

```shell
cd code
make terrat        # builds terrat-oss/ee/ttm/code-indexer + iris UI assets
make test-terrat   # runs the test suite
```

Targets are also reachable directly via dune from the repository root:

```shell
dune build code/src/terrat_oss/terrat_oss.exe
dune runtest code/tests/
```

`dune-workspace` pins `(profile release)` as the default; pass `--profile dev`
or set `DUNE_PROFILE=dev` for a debug build.

Dune writes its merlin configuration as part of `dune build`, so VS Code / OCaml LSP work
out of the box once the switch is active (`eval $(opam env)`).
