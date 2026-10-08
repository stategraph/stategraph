#!/usr/bin/env bash
# Generate docker/terrat/Dockerfile from docker/stategraph/Dockerfile (the source
# of truth), using cog. Blocks shared between the two are delimited with
# `# region:NAME` / `# endregion:NAME` in the stategraph Dockerfile and pulled in
# by the cog blocks (`# [[[cog ... ]]]`) in docker/terrat/Dockerfile.
#
#   render.sh            regenerate docker/terrat/Dockerfile in place
#   render.sh --check    exit non-zero if the committed file is stale (CI gate)
#
# Requires cogapp (`pip install cogapp`, or `pipx install cogapp`).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COG="${COG:-cog}"
TARGET="$ROOT/docker/terrat/Dockerfile"

if [ "${1:-}" = "--check" ]; then
  if $COG --check "$TARGET" >/dev/null; then
    echo "docker/terrat/Dockerfile is up to date"
  else
    echo "stale: docker/terrat/Dockerfile — run docker/terrat/render.sh and commit the result" >&2
    exit 1
  fi
else
  $COG -r "$TARGET"
  echo "wrote docker/terrat/Dockerfile"
fi
