---
title: Private runners
description: Run Stategraph Orchestration plans and applies on self-hosted GitHub Actions runners or GitLab runners in your own network or cluster.
order: 5
---


Stategraph Orchestration runs plans and applies as CI jobs: GitHub Actions workflow runs, or GitLab CI pipeline jobs. A self-hosted runner, also called a private runner, runs these jobs on infrastructure that you control. The Stategraph server does not run your plans and applies.

With a private runner, you:

- control the machines, their environment, their resources, and their tools
- reach private resources, such as internal APIs, databases, or module registries
- meet security or regulatory requirements to run on your own infrastructure

## Set up a private runner

On GitHub, run the runner in a container or set it up by hand. On GitLab, use GitLab Runner.

### GitHub

By default, Orchestration jobs on GitHub run on GitHub-hosted runners.

#### Running in a container

Use GitHub's official [runner image](https://github.com/actions/runner/pkgs/container/actions-runner) (`ghcr.io/actions/actions-runner`), or [Actions Runner Controller](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller) on Kubernetes. Register the runner with a label, and point the job at that label in `.github/workflows/stategraph.yml`:

```yaml
jobs:
  terrateam:
    permissions:
      id-token: write
      contents: read
    runs-on: stategraph-self-hosted
```

!!! note "Deprecated runner image"
    The `ghcr.io/terrateamio/self-hosted-runner` image gets no updates, but you can still pull its tags. Move to GitHub's official runner image or a manual setup.

#### Manual setup

1. Provision a machine or virtual machine that can run GitHub Actions workflows, with network access to GitHub and to the resources of your plans.
2. Download the runner application for your operating system from the GitHub Actions releases page, and extract it.
3. Run `config.sh` (Linux and macOS) or `config.cmd` (Windows) to register the runner, and choose whether to run it as a service.
4. Start it with `run.sh` or `run.cmd`. The runner registers with your repository and waits for jobs.
5. Point the job at the runner in `.github/workflows/stategraph.yml`:

```yaml
jobs:
  terrateam:
    permissions:
      id-token: write
      contents: read
    runs-on: self-hosted
```

With more than one runner, replace `self-hosted` with the label or name of your runner. Commit and push the change. For the full procedure, see GitHub's [self-hosted runner documentation](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners).

### GitLab

On GitLab, Orchestration selects runners by tag. It gives the `runs_on` value of the workflow to the pipeline as the `RUNS_ON` input: the list of runner tags in the `.gitlab-ci.yml` template. Without `runs_on`, the job has no tags, and runs on any runner that accepts untagged jobs.

1. Install [GitLab Runner](https://docs.gitlab.com/runner/) on a machine, container, or Kubernetes cluster that you control, with network access to your GitLab instance and to the resources of your plans.
2. Create a project runner under **Settings > CI/CD > Runners**, or a group runner for all projects in the group. Give it a tag, such as `stategraph-private`.
3. Register the runner with the token that GitLab shows, and start it.
4. In `.stategraph/config.yml`, set `runs_on` on the workflow to a list of the runner's tags:

```yaml
workflows:
  - tag_query: ""
    runs_on: [stategraph-private]
```

Give `runs_on` as a list, because the template input is an array. Commit and push the change.

## Next steps

- [Hardening AWS OIDC](/docs/orchestration/security/hardening-aws-oidc): require `runner_environment:self-hosted` in the trust policy.
- [Self-signed certificates](/docs/orchestration/security/self-signed-certificates): trust internal CAs from the runner.
- [Runs-on](/docs/orchestration/workflows/advanced/runs-on): choose the runner per workflow from `.stategraph/config.yml`.
