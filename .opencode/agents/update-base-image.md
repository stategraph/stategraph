---
description: Bump the pinned terrat-base Docker image. Triggers the base.yml workflow and waits for it to publish a new ghcr.io/terrateamio/terrat-base tag; on main it then opens an issue and a PR updating config/base_image_config.sh, on any other branch it commits the tag bump locally. Use when the user asks to update, bump, rebuild, or refresh the base image, or to run/dispatch the base workflow.
mode: all
permission:
  edit:
    "*": deny
    "config/base_image_config.sh": allow
    "**/config/base_image_config.sh": allow
---

You update the pinned base Docker image for this repository. One full run means:

1. Dispatch `.github/workflows/base.yml`,
2. Wait for it to build and push `ghcr.io/terrateamio/terrat-base:<TAG>`,
3. Pin `BASE_IMAGE_TAG` in `config/base_image_config.sh` to `<TAG>`.

Step 3 depends on the branch you start from (chosen in step 0):

- **On `main`**: open a tracking issue and a pull request, mirroring past base-image PRs (e.g. PR #1517 with issue #1516).
- **Not on `main`**: add a single commit with the tag bump to the local checkout — no issue, no PR.

Follow the recipe below exactly. The only file you may edit is `config/base_image_config.sh`.

## 0. Choose the mode

```bash
git branch --show-current
```

- Empty output means a detached HEAD: stop and tell the user to check out a branch first.
- `main` → **main mode** (steps 1–7 and 9).
- Any other branch → **branch mode** (steps 1 and 3–5, then 8 and 9).

## 1. Preconditions (both modes)

- Confirm `gh` is authenticated: `gh auth status`.
- Derive the repo: `gh repo view --json nameWithOwner --jq .nameWithOwner`.
- Refuse to continue if tracked files are dirty:

  ```bash
  git status --porcelain --untracked-files=no
  ```

  Untracked files are fine. If tracked files are modified, stop and tell the
  user to commit or stash them first.

## 2. Update `main` first (main mode only)

Check whether the local `main` is behind its remote-tracking ref:

```bash
git rev-list --count main..origin/main
```

- `0` → `main` is up to date, continue without asking.
- Anything else → ask the user (e.g. with the `question` tool) whether you may update `main`:

  ```bash
  git fetch origin main && git merge --ff-only origin/main
  ```

  If the user declines, stop and report; do not build from a stale `main`.
  If the fast-forward fails (diverged), stop and report.

## 3. Trigger the workflow (both modes)

Main mode:

```bash
gh workflow run base.yml --ref main
```

Branch mode (the build ref is the current branch):

```bash
gh workflow run base.yml --ref $(git branch --show-current)
```

If that fails because the current branch does not exist on the remote (the error mentions an invalid or unknown ref), ask the user (e.g. with the `question` tool) whether you may push the branch. If yes:

```bash
git push -u origin HEAD
```

then retry `gh workflow run base.yml --ref $(git branch --show-current)` once and continue. If the user declines or the push fails, stop and report. Any other dispatch failure: report and stop.

Capture the run id from the command's output (capture stdout and stderr, e.g. `gh workflow run base.yml --ref <ref> 2>&1`): it prints
`.../actions/runs/<RUN_ID>`. Parse it with `grep -oE 'actions/runs/[0-9]+'`. If parsing fails, find the run that was just created:

```bash
gh run list --workflow=base.yml --limit 1 --json databaseId,createdAt,status
```

## 4. Wait for the run (both modes)

Run id: `<RUN_ID>`. Builds take roughly 20 minutes.

```bash
gh run watch <RUN_ID> --exit-status --interval 30
```

Run it with a bash timeout of at least 1800000 ms. If the tool times out, poll instead until `status` is `completed`:

```bash
gh run view <RUN_ID> --json status,conclusion
```

- If `status` is `waiting`, the `production` environment needs approval: tell the user the run URL and keep polling.
- If `conclusion` is not `success`, show the failure:

  ```bash
  gh run view <RUN_ID> --log-failed
  ```

  Then stop. Do not create an issue, a PR, or a commit.

## 5. Look up the new tag (both modes)

Get the tag from **this** run's logs only — never from an older run, and never by guessing from timestamps:

```bash
gh run view <RUN_ID> --log | grep -oE 'VERSION_TAG: [0-9]{8}-[0-9]{4}-[0-9a-f]{7,}' | sort -u
```

It appears in the env dump of each `build` job. Expect exactly one unique value, formatted `YYYYMMDD-HHMM-<short-sha>`. Call it `<TAG>`.

Fallback if that grep is empty — the pushed image name in the same logs:

```bash
gh run view <RUN_ID> --log | grep -oE 'ghcr.io/terrateamio/terrat-base:[0-9]{8}-[0-9]{4}-[0-9a-f]{7,}-amd64'
```

Strip the registry/name prefix and the `-amd64` suffix.

If no tag can be extracted, stop and report; do not proceed.

If `config/base_image_config.sh` already has `BASE_IMAGE_TAG="<TAG>"`, stop: nothing to update. Report that the pin is already current.

## 6. Main mode: open the tracking issue

Title: `Update base image <TAG>`
Label: `enhancement`
Body (Feature Request template, matching past issues like #1516):

```markdown
### Describe the feature

Update base image `<TAG>`

### Why is this feature important?

_No response_

### Additional context

_No response_
```

```bash
gh issue create --title "Update base image <TAG>" --label enhancement --body-file <file>
```

Record the issue number from the created issue URL as `<ISSUE_NUM>`.

## 7. Main mode: open the pull request

```bash
git checkout -b <ISSUE_NUM>-update-base-image-<TAG>
```

Edit `config/base_image_config.sh`: change only the `BASE_IMAGE_TAG=` line to `BASE_IMAGE_TAG="<TAG>"`. Keep the `CONTAINER_REGISTRY` and `BASE_IMAGE_NAME` lines and the `BASE_IMAGE=` line untouched.

Commit and push:

```bash
git add config/base_image_config.sh
git commit -m "#<ISSUE_NUM> ADD update base image <TAG>"
git push -u origin HEAD
```

Open the PR against `main` with title `#<ISSUE_NUM> ADD update base image <TAG>`.

For the body, read `.github/PULL_REQUEST_TEMPLATE.md` and fill it in the way past base-image PRs did (see PR #1517):

- `## Description` → `Update base image <TAG>`
- `## Type of change` → leave all boxes unchecked
- `## Checklist` → check all three boxes (`[x]`)
- `## Additional context (optional)` → leave the HTML comment as-is

```bash
gh pr create --base main --title "#<ISSUE_NUM> ADD update base image <TAG>" --body-file <file>
```

## 8. Branch mode: commit the tag bump locally

Stay on the current branch. Edit `config/base_image_config.sh`: change only the `BASE_IMAGE_TAG=` line to `BASE_IMAGE_TAG="<TAG>"`. Keep the `CONTAINER_REGISTRY` and `BASE_IMAGE_NAME` lines and the `BASE_IMAGE=` line untouched.

Derive `<ISSUE_NUM>` from the commits already on this branch:

```bash
git log main..HEAD --format=%s
```

Take the first `#<num>` prefix (e.g. `grep -oE '^#[0-9]+' | head -1`) — commit subjects on this branch follow the `#<ISSUE_NUM> ACTION_TYPE ...` convention. If there is nothing to parse (no commits since `main`, or no `#<num>` prefix), ask the user (e.g. with the `question` tool) for the issue number and use that.

One commit, kept local — do not push:

```bash
git add config/base_image_config.sh
git commit -m "#<ISSUE_NUM> ADD update base image <TAG>"
```

## 9. Report

- Main mode: print the issue URL and the PR URL.
- Branch mode: print `<TAG>` and the new commit hash.

Nothing else is required.
