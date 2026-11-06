---
title: GitHub Actions
description: Plan on pull requests and apply on merge with the Stategraph CLI in GitHub Actions, with no app to install.
order: 2
---

Run Infrastructure as a Database in plain GitHub Actions: install the CLI on the runner, export three variables, and replace `terraform plan` and `terraform apply` with `stategraph plan` and `stategraph apply`. Plans run on pull requests. The apply runs when the change lands on your default branch.

## Before you begin

- A Stategraph server that GitHub's runners can reach: [Stategraph Cloud](https://app.stategraph.cloud) or a [self-hosted](/docs/admin/self-hosting) deployment.
- A Stategraph API key and tenant. See [Setup](/docs/infrastructure-as-a-database/setup).
- Your state imported once, with `stategraph.json` committed. See [Import your Terraform state](/docs/get-started/quickstart/import-state).
- The API key in a repository or environment secret named `STATEGRAPH_API_KEY`.

## Workflow

```yaml
name: Stategraph
on:
  pull_request:
    paths: ['infra/**']
  push:
    branches: [main]
    paths: ['infra/**']

env:
  STATEGRAPH_API_BASE: https://stategraph.example.com
  STATEGRAPH_API_KEY: ${{ secrets.STATEGRAPH_API_KEY }}
  STATEGRAPH_TENANT_ID: your-tenant-id

jobs:
  plan:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    defaults: { run: { working-directory: infra } }
    steps:
      - uses: actions/checkout@v7
      - uses: opentofu/setup-opentofu@v2
        with: { tofu_wrapper: false }
      - name: Install Stategraph CLI
        run: curl -fsSL https://get.stategraph.com/install.sh | sh
      - name: Plan
        id: plan
        shell: bash
        continue-on-error: true
        run: stategraph plan 2>&1 | tee plan.txt
      - name: Comment plan on PR
        shell: bash
        env:
          GH_TOKEN: ${{ github.token }}
          PR: ${{ github.event.pull_request.number }}
          OUTCOME: ${{ steps.plan.outcome }}
        run: |
          {
            echo '<!-- stategraph-plan -->'
            echo "#### Stategraph Plan \`${OUTCOME}\`"
            echo '<details><summary>Show plan</summary>'
            echo
            echo '```'
            cat plan.txt
            echo '```'
            echo '</details>'
            echo
            echo "*Pusher: @${GITHUB_ACTOR}, Action: \`${GITHUB_EVENT_NAME}\`*"
          } > comment.md
          cid=$(gh api "repos/${GITHUB_REPOSITORY}/issues/${PR}/comments" --jq '[.[] | select(.body | startswith("<!-- stategraph-plan -->"))][0].id')
          if [ -n "$cid" ] && [ "$cid" != "null" ]; then
            gh api -X PATCH "repos/${GITHUB_REPOSITORY}/issues/comments/${cid}" -F body=@comment.md > /dev/null
          else
            gh pr comment "$PR" --body-file comment.md > /dev/null
          fi
      - name: Fail the job if the plan failed
        if: steps.plan.outcome == 'failure'
        run: exit 1

  apply:
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    defaults: { run: { working-directory: infra } }
    steps:
      - uses: actions/checkout@v7
      - uses: opentofu/setup-opentofu@v2
        with: { tofu_wrapper: false }
      - name: Install Stategraph CLI
        run: curl -fsSL https://get.stategraph.com/install.sh | sh
      - name: Apply
        id: apply
        shell: bash
        continue-on-error: true
        run: stategraph apply --auto-approve 2>&1 | tee apply.txt
      - name: Comment apply on the merged PR
        shell: bash
        env:
          GH_TOKEN: ${{ github.token }}
          OUTCOME: ${{ steps.apply.outcome }}
        run: |
          pr=$(gh api "repos/${GITHUB_REPOSITORY}/commits/${GITHUB_SHA}/pulls" --jq '.[0].number')
          if [ -z "$pr" ] || [ "$pr" = "null" ]; then
            echo "no associated PR; apply output stays in the job log"
            exit 0
          fi
          {
            echo "#### Stategraph Apply \`${OUTCOME}\`"
            echo '<details><summary>Show apply</summary>'
            echo
            echo '```'
            cat apply.txt
            echo '```'
            echo '</details>'
          } > comment.md
          gh pr comment "$pr" --body-file comment.md > /dev/null
      - name: Fail the job if the apply failed
        if: steps.apply.outcome == 'failure'
        run: exit 1
```

- The plan job keeps one sticky comment per pull request, found by its `<!-- stategraph-plan -->` marker and updated on each push. `gh` ships on GitHub-hosted runners.
- A failed plan still comments, with a `failure` badge and the error, and then fails the job.
- After the merge, the apply job comments its result, success or failure, on the source pull request, found through the merge commit.
- `stategraph apply --auto-approve` plans and applies in one step, so the apply reflects the merge result, with no stale plan file between jobs.
- The CLI runs OpenTofu or Terraform. `setup-opentofu` installs OpenTofu. If the runner has both, set `TF_CMD` in `env`.

## Concurrent pull requests

Stategraph detects conflicts per resource, not per state file. Pull requests that touch different resources plan and apply independently. A real overlap fails the second apply at commit, with the conflicting transaction ID. To retry, run the job again. It plans again. You need no `force-unlock` and no queue.

## The Orchestration path

Stategraph Orchestration runs this flow on your GitHub Actions runners, with no hand-written workflow. It posts the plan as a comment and a commit check, enforces apply requirements, policy, and access control, and applies on a `stategraph apply` comment or on merge. See [Workflows](/docs/orchestration/workflows).

To plan through Infrastructure as a Database, connect the repository (see [Quickstart](/docs/get-started/quickstart)), and set `engine: stategraph` in `.stategraph/config.yml`. See [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration).

## Next Steps

- [Setup](/docs/infrastructure-as-a-database/setup): state import and CLI configuration.
- [GitLab CI](/docs/infrastructure-as-a-database/ci/gitlab-ci): the same flow on GitLab.
- [Transactions](/docs/infrastructure-as-a-database/transactions): what an apply commits.
