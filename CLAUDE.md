# Psyching up
- You are a professional OCaml developer
- You are fantastic at matching the style of an existing project.
- When you don't know how to do something, you consult the existing code in the project and match it.

# Dune and make files
- The build is dune-driven. `code/Makefile` is a thin wrapper that delegates to `dune` from the repo root (where `dune-project` lives).
- To add or change a library's dependencies, edit its `code/src/<name>/dune` directly.
- New code conventionally lives in `code/src/<name>/` with a small `dune` declaring `(library (name <name>) (libraries ...))`. Tests live in `code/tests/<name>/` with `(test (name test) (libraries ...))`.

# Editing Ocaml files
- After editing an Ocaml file, run `ocamlformat -i code/src/<module>/<filename>`
- After an edit, build the relevant `make` target to verify the change is correct.

# Building
- To build a target run `make -j$(nproc) <target>` from `code/` (or `make -C code -j$(nproc) <target>` from the repo root).
- To regenerate the OCaml API types from the schemas run `make generate-api-types` (or `dune build @code/generate-api-types`); to verify they are up-to-date run `make check-api-types`.
- To build Terrateam client and server run `make terrat`.
- Targets are also reachable directly via dune from the repo root, e.g. `dune build code/src/terrat_oss/terrat_oss.exe`. `dune-workspace` pins `(profile release)` as the default; the devcontainer overrides via `DUNE_PROFILE=dev`.
- Always use `tail` to reduce the amount of data being processed when building.
- If building fails, run `make <target>` (from `code/`) and use `tail` to get the build error.

# Testing
- To run tests: `make test-terrat` from `code/` (runs `dune runtest code/tests/`).
- Unit tests go in `code/tests/<name>` where `<name>` matches the library in `code/src/<name>`.

# Style
- When using long module names, create a short alias name using `let module`, i.e. `let module <short_name> = <long name> in`.
- Always use snakecase in identifier names.  For example prefer `String_set` in place of `StringSet`.
- When doing a local module open to construct or match against a record, always use `{ Module. field; ... }` instead of `Module.{ field; ... }`.
- When making new types, prefer to create a new module with a single `type t`.
- Errors are represented as polymorphic variants. The type name will be `err` or end in `_err`. All polymorphic variant constructors will end in `_err`. The type will derive the show ppx, e.g. `type err = [ \`Some_err ] [@@deriving show]`.
