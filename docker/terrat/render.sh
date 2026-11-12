#!/usr/bin/env bash
# Generate docker/terrat/Dockerfile.fips, in part, from docker/stategraph/Dockerfile
# (the source of truth), using cog. Blocks shared with it are delimited with
# `# region:NAME` / `# endregion:NAME` in the stategraph Dockerfile and pulled in
# by the cog blocks (`# [[[cog ... ]]]`) in the generated file.
#
#   render.sh            regenerate the generated files in place
#   render.sh --check    exit non-zero if a committed file is stale (CI gate)
#
# Requires cogapp (`pip install cogapp`, or `pipx install cogapp`).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COG="${COG:-cog}"
TARGETS=(docker/terrat/Dockerfile.fips)

stale=0
for target in "${TARGETS[@]}"; do
  if [ "${1:-}" = "--check" ]; then
    if $COG --check "$ROOT/$target" >/dev/null; then
      echo "$target is up to date"
    else
      echo "stale: $target — run docker/terrat/render.sh and commit the result" >&2
      stale=1
    fi
  else
    $COG -r "$ROOT/$target"
    echo "wrote $target"
  fi
done
exit "$stale"
