---
title: GitHub Reusable Workflows
description: Centralize the Orchestration GitHub Actions workflow in one repository and call it from every Terraform repository with a small workflow_call caller.
order: 14
---


A GitHub reusable workflow keeps the Stategraph Orchestration GitHub Actions workflow in one repository, and each of your other repositories calls it with a small caller workflow. Without it, each repository keeps its own copy of the workflow. With a reusable workflow:

- You update the workflow in one place, and every caller gets the change.
- Every team runs the same workflow.
- You control who can change the workflow, and you manage secrets in one place.
- You enforce organization standards in one file.

!!! note "Workflow updates"
    The Orchestration workflow file changes as features are added. Start from the current standard workflow. The console shows it under **Get Started** when you set up a repository, and there is a [reference copy](https://github.com/stategraph/kick-the-tires/blob/main/.github/workflows/stategraph.yml).

## Setting up a reusable workflow

### 1. Create the workflow repository

Create a repository for the reusable workflow, for example `stategraph-workflows`.

### 2. Create the reusable workflow file

In that repository, create `.github/workflows/orchestration.yml` from the current standard workflow. Make these changes:

- Change the trigger from `workflow_dispatch` to `workflow_call`.
- Add `type: string` to every string input. `workflow_call` requires it.
- Keep the `environment` input as `type: string`.
- Keep every other step and setting.

The standard workflow uses:

```yaml
on:
  workflow_dispatch:
    inputs:
      work-token:
        description: 'Work Token'
        required: true
```

The reusable workflow uses:

```yaml
on:
  workflow_call:
    inputs:
      work-token:
        description: 'Work Token'
        required: true
        type: string
```

The result:

```yaml
name: 'Stategraph Reusable Workflow'
on:
  workflow_call:
    inputs:
      work-token:
        description: 'Work Token'
        required: true
        type: string
      api-base-url:
        description: 'API Base URL'
        type: string
      environment:
        description: 'Environment in which to run the action'
        type: string
      runs_on:
        description: 'runs-on configuration'
        type: string
        default: '"ubuntu-latest"'

jobs:
  stategraph:
    # Copy the jobs section from the standard workflow unchanged
    permissions:
      id-token: write
      contents: read
    runs-on: ${{ fromJSON(inputs.runs_on) }}
    timeout-minutes: 1440
    name: Stategraph Orchestration
    environment: '${{ inputs.environment }}'
    steps:
      # Steps stay the same as the standard workflow
      - run: echo "copy the steps from the standard workflow"
```

### 3. Create the caller workflow

In each repository that runs Orchestration, create `.github/workflows/stategraph.yml`. Orchestration dispatches this exact path. The caller declares the same inputs as the standard workflow and passes them through:

```yaml
name: 'Stategraph Orchestration'
on:
  workflow_dispatch:
    inputs:
      # Copy every input from the standard workflow.
      # They must match what Orchestration sends.
      work-token:
        description: 'Work Token'
        required: true
      api-base-url:
        description: 'API Base URL'
      environment:
        description: 'Environment in which to run the action'
        type: environment
      runs_on:
        description: 'runs-on configuration'
        type: string
        default: '"ubuntu-latest"'

jobs:
  stategraph:
    uses: YOUR_ORG/stategraph-workflows/.github/workflows/orchestration.yml@main
    with:
      work-token: '${{ github.event.inputs.work-token }}'
      api-base-url: '${{ github.event.inputs.api-base-url }}'
      environment: '${{ github.event.inputs.environment }}'
      runs_on: '${{ github.event.inputs.runs_on }}'
    secrets: inherit
```

The caller uses `type: environment` for the `environment` input, and the reusable workflow uses `type: string`. `secrets: inherit` passes every repository secret to the reusable workflow.

!!! warning "Before you commit"
    Replace `YOUR_ORG/stategraph-workflows` with your organization and repository. When the standard workflow changes, update the caller's inputs to match. To pin the version that each repository uses, replace `@main` with a tag or a commit SHA.

### 4. Set repository visibility

The callers must be able to see the workflow repository:

- For use across your organization, make it **Internal** or **Public**.
- For public repositories that call it, make it **Public**.

### 5. Test

Open a pull request in a repository that uses the caller workflow. Make sure that the plan runs and posts its comment as usual.

## Next steps

- [Custom runners](/docs/orchestration/workflows/advanced/runs-on): the `runs_on` input the workflow passes through.
- [Private runners](/docs/orchestration/security/private-runners)
- [Pull request workflow](/docs/orchestration/workflows)
