#!/usr/bin/env bash
# API type drift check for the console, the counterpart of `make -C code
# check-api-types` (code/Makefile). Regenerates lib/api/types-generated.ts from
# api.json and fails if the committed file changes.
#
# jj is preferred whenever the checkout is a jj workspace, including a colocated
# one: there, the comparison runs against the working copy's own state before
# the generation -- the commit id of @ is captured before and after, `jj log`
# snapshots the working copy first, so the id changes exactly when the
# generation changed a file -- and the two commits are diffed over the generated
# file. An empty diff means the file is in sync. A `git diff` in a colocated
# checkout would compare the worktree with the index jj exported last, which can
# miss a drift another tool staged. A plain git clone falls back to
# `git diff --exit-code`: worktree against index.
set -u

cd "$(dirname "$0")/.." || exit 1

if command -v jj >/dev/null 2>&1 && jj root >/dev/null 2>&1; then
  before="$(jj log -r @ --no-graph -T commit_id 2>/dev/null)" || {
    echo 'ERROR: cannot read the commit id of the jj working copy.' >&2
    exit 1
  }
  npm run generate-api-types || exit 1
  after="$(jj log -r @ --no-graph -T commit_id)"
  if [ "$before" != "$after" ]; then
    drift="$(jj diff --from "$before" --to "$after" -s -- lib/api/types-generated.ts)" || exit 1
    if [ -n "$drift" ]; then
      printf '%s\n' "$drift"
      echo 'ERROR: API types are out of sync. Run npm run generate-api-types and commit the file.'
      exit 1
    fi
  fi
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  npm run generate-api-types || exit 1
  if ! git diff --exit-code -- lib/api/types-generated.ts; then
    echo 'ERROR: API types are out of sync. Run npm run generate-api-types and commit the file.'
    exit 1
  fi
else
  echo 'ERROR: cannot compare generated files: not a git work tree and not a jj repo.' >&2
  exit 1
fi
