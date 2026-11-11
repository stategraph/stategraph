---
title: Run Titles
description: "Name each Stategraph Orchestration run on GitHub Actions after what it does, with inputs the workflow declares and its run-name."
order: 15
---


Each Stategraph Orchestration run on GitHub Actions shows the name of the workflow file, so a list of runs does not say which run planned or applied which directory. Declare any of the inputs below under `workflow_dispatch` and use them in `run-name`. Stategraph Orchestration fills in each input your workflow declares when it starts the run.

| Input | Value |
|-------|-------|
| `run-type` | `plan`, `apply`, `unsafe-apply`, `build-config`, `build-tree` or `index` |
| `run-kind` | `pr` or `drift` |
| `pr-number` | The pull request number. Not set for drift. |
| `pr-title` | The pull request title. Not set for drift. |
| `dirspaces` | The directories of the run, with `:workspace` after a directory whose workspace is not `default`. After three, the rest are counted, as in `prod/app, prod/db, prod/net +2 more`. |

## Example

```yaml
name: 'Stategraph'
run-name: "${{ inputs.run-type }} ${{ inputs.dirspaces }}"
on:
  workflow_dispatch:
    inputs:
      # The work-token and api-base-url are passed in by the backend
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
      run-type:
        default: ''
      dirspaces:
        default: ''
```

The runs then show titles such as `plan environments/dev, environments/prod`.

An input your workflow does not declare is not sent, so a workflow without these inputs starts as before.
