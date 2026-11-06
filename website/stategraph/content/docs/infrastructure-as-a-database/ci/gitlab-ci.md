---
title: GitLab CI
description: Plan on merge requests and apply on merge with the Stategraph CLI in GitLab CI, with results on the merge request.
order: 3
---

Run Infrastructure as a Database in plain GitLab CI: install the CLI on the runner, export three variables, and replace `terraform plan` and `terraform apply` with `stategraph plan` and `stategraph apply`. Plans run on merge requests. The apply runs on merge to your default branch.

## Before you begin

- A Stategraph server that your GitLab runners can reach: [Stategraph Cloud](https://app.stategraph.cloud) or a [self-hosted](/docs/admin/self-hosting) deployment.
- A Stategraph API key and tenant. See [Setup](/docs/infrastructure-as-a-database/setup).
- Your state imported once, with `stategraph.json` committed. See [Import your Terraform state](/docs/get-started/quickstart/import-state).
- Two masked CI/CD variables on the project:

| Variable | Value |
|----------|-------|
| `STATEGRAPH_API_KEY` | Your Stategraph API key |
| `COMMENT_TOKEN` | A project or personal access token with `api` scope, to post merge request notes. `CI_JOB_TOKEN` cannot write notes |

The plan job runs in merge request pipelines on the source branch. GitLab passes protected variables only to pipelines on protected branches, so leave both variables unprotected unless every source branch is protected.

## Pipeline

```yaml
stages: [plan, apply]

default:
  image: alpine:3.20

variables:
  STATEGRAPH_API_BASE: https://stategraph.example.com
  STATEGRAPH_TENANT_ID: your-tenant-id

.install: &install
  - apk add --no-cache curl jq >/dev/null
  - |
    VERSION=$(curl -s https://api.github.com/repos/stategraph/releases/releases/latest | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)
    curl -fsSL https://github.com/stategraph/releases/releases/download/$VERSION/stategraph-$VERSION-linux-amd64.tar.gz | tar xz -C /usr/local/bin stategraph
  - curl -fsSL https://github.com/opentofu/opentofu/releases/download/v1.8.8/tofu_1.8.8_linux_amd64.tar.gz | tar xz -C /usr/local/bin tofu

plan:
  stage: plan
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes: [infra/**/*]
  script:
    - *install
    - cd infra
    - rc=0; stategraph plan > plan.txt 2>&1 || rc=$?
    - cat plan.txt
    - outcome=success; [ "$rc" -ne 0 ] && outcome=failure
    - |
      {
        echo '<!-- stategraph-plan -->'
        echo "#### Stategraph Plan \`${outcome}\`"
        echo '<details><summary>Show plan</summary>'
        echo
        echo '```'
        cat plan.txt
        echo '```'
        echo '</details>'
        echo
        echo "*Pusher: @${GITLAB_USER_LOGIN}, Action: \`${CI_PIPELINE_SOURCE}\`*"
      } > note.md
    - |
      nid=$(curl -s -H "PRIVATE-TOKEN: $COMMENT_TOKEN" "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/notes?per_page=100" | jq -r '[.[] | select(.body | startswith("<!-- stategraph-plan -->"))][0].id')
      if [ "$nid" != "null" ] && [ -n "$nid" ]; then
        curl -s -X PUT -H "PRIVATE-TOKEN: $COMMENT_TOKEN" --data-urlencode "body@note.md" "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/notes/$nid" > /dev/null
      else
        curl -s -X POST -H "PRIVATE-TOKEN: $COMMENT_TOKEN" --data-urlencode "body@note.md" "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/notes" > /dev/null
      fi
    - exit $rc

apply:
  stage: apply
  rules:
    - if: $CI_PIPELINE_SOURCE == "push" && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      changes: [infra/**/*]
  script:
    - *install
    - cd infra
    - rc=0; stategraph apply --auto-approve > apply.txt 2>&1 || rc=$?
    - cat apply.txt
    - outcome=success; [ "$rc" -ne 0 ] && outcome=failure
    - |
      iid=$(curl -s -H "PRIVATE-TOKEN: $COMMENT_TOKEN" "$CI_API_V4_URL/projects/$CI_PROJECT_ID/repository/commits/$CI_COMMIT_SHA/merge_requests" | jq -r '.[0].iid')
      if [ "$iid" != "null" ] && [ -n "$iid" ]; then
        {
          echo "#### Stategraph Apply \`${outcome}\`"
          echo '<details><summary>Show apply</summary>'
          echo
          echo '```'
          cat apply.txt
          echo '```'
          echo '</details>'
        } > note.md
        curl -s -X POST -H "PRIVATE-TOKEN: $COMMENT_TOKEN" --data-urlencode "body@note.md" "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$iid/notes" > /dev/null
      fi
    - exit $rc
```

- The plan job keeps one merge request note, found by its `<!-- stategraph-plan -->` marker and updated on each push. A failed plan still posts the note, with a `failure` badge and the error, and then fails the job.
- After the merge, the apply job posts its result, success or failure, on the source merge request, found through the merge commit. A direct push without a merge request keeps the output in the job log only.
- `stategraph apply --auto-approve` plans and applies in one step, so the apply reflects the merge result, with no stale plan file between jobs.
- The CLI runs OpenTofu or Terraform. Both binaries in the install snippet are static, so any Linux image works, Alpine included. If the image has both, set `TF_CMD` in `variables`.

## Concurrent merge requests

Stategraph detects conflicts per resource, not per state file. Merge requests that touch different resources plan and apply independently. A real overlap fails the second apply at commit, with the conflicting transaction ID. To retry, run the job again. It plans again. You need no `force-unlock` and no queue.

## The Orchestration path

Stategraph Orchestration runs this flow on your GitLab CI runners, with no hand-written pipeline. It posts the plan as a comment and an apply commit status, enforces apply requirements, policy, and access control, and applies on a `stategraph apply` comment or on merge. See [Workflows](/docs/orchestration/workflows).

To plan through Infrastructure as a Database, connect the group (see [Quickstart](/docs/get-started/quickstart)), and set `engine: stategraph` in `.stategraph/config.yml`. See [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration).

## Next Steps

- [Setup](/docs/infrastructure-as-a-database/setup): state import and CLI configuration.
- [GitHub Actions](/docs/infrastructure-as-a-database/ci/github-actions): the same flow on GitHub.
- [Transactions](/docs/infrastructure-as-a-database/transactions): what an apply commits.
