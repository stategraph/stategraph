---
title: Custom Runners
description: Choose the GitHub Actions or GitLab CI runners that execute plan and apply with the runs_on workflow key, using runner labels or runner tags.
order: 6
---


The `runs_on` key of a workflow selects the CI runner that runs its plans and applies. On GitHub Actions it becomes the job's `runs-on` value. On GitLab CI it is a list of runner tags. Use it to:

- Run sensitive workloads on self-hosted runners, for security, compliance, or network reasons.
- Target runner labels or tags for specific hardware or preinstalled tools.
- Spread work across runner pools.
- Meet policies that require on-premises execution.

Without `runs_on`, Stategraph Orchestration runs on GitHub-hosted `ubuntu-latest` runners on GitHub. On GitLab, the job has no runner tags, so any runner that accepts untagged jobs can take it.

## Configuration

Set `runs_on` on a workflow entry in `.stategraph/config.yml`. See the [workflows reference](/docs/reference/orchestration/configuration/workflows). On GitHub, `runs_on` accepts any valid GitHub Actions runner specification:

```yaml
workflows:
  - tag_query: ""
    runs_on: ubuntu-latest
```

On GitLab, write `runs_on` as a list of runner tags, even for a single tag, because the `RUNS_ON` pipeline input is an array.

### Self-hosted runner

On GitHub, a single label can be a plain string:

```yaml
workflows:
  - tag_query: "production"
    runs_on: self-hosted
    plan:
      - type: init
      - type: plan
    apply:
      - type: init
      - type: apply
```

### Multiple labels

To match several labels on GitHub, or several tags on GitLab, use a list:

```yaml
workflows:
  - tag_query: "production"
    runs_on: [self-hosted, linux, x64, gpu]
    plan:
      - type: init
      - type: plan
```

### Single label as a list

A single label can also be a list:

```yaml
workflows:
  - tag_query: ""
    runs_on: ["self-hosted"]
```

## Environment-specific runners

Give each environment its own runner selection, for example when environments have different security requirements:

```yaml
workflows:
  - tag_query: "dev"
    runs_on: ubuntu-latest
    plan:
      - type: init
      - type: plan
    apply:
      - type: init
      - type: apply

  - tag_query: "staging"
    runs_on: [self-hosted, staging, linux]
    plan:
      - type: init
      - type: plan
    apply:
      - type: init
      - type: apply

  - tag_query: "production"
    runs_on: [self-hosted, production, secure, linux]
    plan:
      - type: init
      - type: plan
    apply:
      - type: init
      - type: apply
```

Development runs on GitHub-hosted runners, staging on self-hosted runners with the `staging` label, and production on a dedicated pool with the `production` and `secure` labels.

On GitLab, leave `runs_on` unset on an entry that can run on any runner that accepts untagged jobs:

```yaml
workflows:
  - tag_query: "dev"
  - tag_query: "staging"
    runs_on: [staging, linux]
  - tag_query: "production"
    runs_on: [production, secure, linux]
```

Development runs on any runner that accepts untagged jobs, staging on runners with the tags `staging` and `linux`, and production on runners with the tags `production`, `secure`, and `linux`.

## CI file requirements

Orchestration sends the `runs_on` value of the matching workflow entry with each run that it starts. The CI file in your repository must pass it to the job.

### GitHub

Orchestration passes the value as JSON in the `runs_on` input of the workflow dispatch. The standard `.github/workflows/stategraph.yml` declares that input with the default `'"ubuntu-latest"'`, and sets `runs-on: ${{ fromJSON(github.event.inputs.runs_on) }}` on the job. [GitHub reusable workflows](/docs/orchestration/workflows/advanced/github-reusable-workflows) shows the same input in a reusable workflow.

### GitLab

Orchestration passes the value in the `RUNS_ON` pipeline input, only when `runs_on` is set.

- The `.gitlab-ci.yml` from the console declares `RUNS_ON` under `spec.inputs` as an array with an empty default. It passes the value to the included template as the runner tags. The **Get Started** page of the console shows the full file.
- If `runs_on` is set and `.gitlab-ci.yml` does not declare `RUNS_ON`, the pipeline does not start. Orchestration then comments on the merge request with the `spec` and `include` blocks that the file needs.

## Next steps

- [Private runners](/docs/orchestration/security/private-runners): set up self-hosted GitHub Actions runners for Orchestration.
- [Tags and tag queries](/docs/orchestration/workflows/advanced/tag-system): the `tag_query` values used above.
- [workflows reference](/docs/reference/orchestration/configuration/workflows)
