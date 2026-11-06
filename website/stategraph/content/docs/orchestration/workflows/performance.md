---
title: Performance
description: Profile a slow Stategraph Orchestration run, then cut startup cost, run fewer directories, run them concurrently, and make each one cheaper.
order: 4
---


Six levers make a slow Stategraph Orchestration run faster. Use them in this order, which usually saves the most:

1. Measure first. Profile the run before you change anything.
2. Cut the fixed startup cost. Each run pays it, whatever the change.
3. Run fewer dirspaces. The cheapest work is the work that you skip.
4. Run dirspaces concurrently, on the runner that you pay for.
5. Make each dirspace cheaper: cut the setup per directory, and the plan itself.
6. Audit your workflow steps. Third-party tools are often the largest remaining cost.

A slow run is rarely one problem. A 45-minute run usually runs more directories than it needs, one at a time, and pays the same setup cost in each one.

!!! tip "Send the profile to support"
    For plan latency, long runtimes, runner sizing, or large Terragrunt graphs, send the profiler output and your `.stategraph/config.yml`. Support reads them with you. [Support](/docs/support) lists where to send them and what to include.

## Measure first

Do not tune from a guess, and make one change per branch: two changes that land together do not tell you which one saved the time.

Each operation writes a full step trace to the CI job log: one line per step, per directory. GitHub Actions adds a timestamp to each line:

```text
2026-08-19T05:17:37.8221006Z INFO:root:STEP : RUN : /github/workspace/live/dev/lambda : {'type': 'init', 'extra_args': []}
2026-08-19T05:17:49.5175714Z INFO:root:STEP : RUN : /github/workspace/live/dev/lambda : {'cmd': ['terragrunt', 'validate'], 'type': 'run'}
2026-08-19T05:17:57.0497046Z INFO:root:STEP : RUN : /github/workspace/live/dev/lambda : {'type': 'plan', 'extra_args': ['-input=false']}
```

The time between two consecutive timestamps of a directory is the cost of a step: the number to optimize.

On GitLab CI, the step lines are the same, but directory paths start with the checkout directory of the job, not `/github/workspace`. The runner writes no timestamps, so a GitLab job log has them only when your GitLab runner adds them.

### Profile a run

The profiler script does this arithmetic for you. Pass it the URL of the slow GitHub job:

```bash
curl -sO https://raw.githubusercontent.com/stategraph/stategraph/main/docs/public/terrateam-run-profile.py
python3 terrateam-run-profile.py https://github.com/OWNER/REPO/actions/runs/12345678901/job/97731319483
```

Or pass the zip from **Download log archive** on the run page, as it is:

```bash
python3 terrateam-run-profile.py logs_32825125903.zip
```

A single log file or an unpacked log directory also works. The profiler needs only Python 3. The URL form also needs the [GitHub CLI](https://cli.github.com), to fetch the log.

On GitLab CI, download the raw log of the job and pass the file. The profiler measures only lines with a UTC timestamp, such as `2026-08-19T05:17:37.822Z`.

Example output, from a real Terragrunt plan of three directories:

```text
Terrateam run 9d9e3c58  |  3 dirspaces  |  terragrunt
=====================================================
  wall clock                78.9s
  step time, summed         53.0s  across all directories
  measurement           3 at least (>); 2 at most (<)
  dirspace concurrency       2.8x  (35.0s of step time in a 12.6s window)

WHERE THE WALL CLOCK WENT
----------------------------------
  runner startup, before Terrateam      40.2s   50.9%  #########.........
  work manifest + repo config            6.5s    8.2%  #.................
  pre hooks                             14.4s   18.3%  ###...............
  dirspace steps                        12.6s   16.0%  ###...............
  post hooks                             3.6s    4.5%  #.................
  teardown after completion              1.6s    2.0%  ..................

STEP TIME BY TYPE
----------------------------------
  init                               26.4s   49.8%  #########......... x3
  infracost_setup                    10.3s   19.5%  ####.............. x1  (1 not exact)
  plan                                6.6s   12.5%  ##................ x3  (3 not exact)
  update_terrateam_github_token       6.1s   11.5%  ##................ x4
  drift_create_issue                  3.6s    6.8%  #................. x1  (1 not exact)

STEP TIME BY DIRSPACE
----------------------------------
  . (hooks, repo root)         18.0s   34.0%  ######............ (2 not exact)
  live/us-east-1/prod/ecs      12.6s   23.8%  ####.............. has changes (1 not exact)
  live/us-east-2/prod/rds      12.2s   23.0%  ####.............. has changes (1 not exact)
  live/us-east-1/prod/rds      10.2s   19.2%  ###............... has changes (1 not exact)

TERRATEAM API TIME  (15.6s, 19.7% of wall clock)
------------------------------------------------
  POST /api/github/v1/work-manifests/{id}/initiate           6.2s   40.0%  #######........... x2
  POST /api/github/v1/work-manifests/{id}/access-token       4.9s   31.7%  ######............ x3
  PUT /api/github/v1/work-manifests/{id}                     2.6s   16.6%  ###............... x1
  POST /api/github/v1/work-manifests/{id}/plans              1.2s    7.8%  #................. x3
  GET /repos/example-org/example-repo/issues                 0.6s    3.9%  #................. x1

SLOWEST INDIVIDUAL STEPS
----------------------------------
  <   10.3s  infracost_setup            .  (at most)
      10.2s  init                       live/us-east-1/prod/ecs
       8.8s  init                       live/us-east-2/prod/rds
       7.4s  init                       live/us-east-1/prod/rds
       4.1s  update_terrateam_github_token .
  <    3.6s  drift_create_issue         .  (at most)

SIGNALS
----------------------------------
  * create_and_select_workspace is on for 3 of 3 dirspaces. If every
    directory uses the default workspace, setting it to false removes one
    tool invocation per dirspace.
  * Terrateam API calls are 20% of the run. That is latency to the Terrateam
    server, not your Terraform.
  * Runner startup is 40s before Terrateam does anything, 51% of the run.
    That is queue, action image build, and checkout.
  * cost estimation (infracost) is enabled in this run.
```

The profiler labels say Terrateam. They mean the Orchestration server and runner.

Read the report in this order:

- **Where the wall clock went** tells you which section of this page you need. Runner startup is the fixed startup cost, not your Terraform. Dirspace step time is for the later sections.
- **Dirspace concurrency**: compare it with `parallel_runs`. With `parallel_runs: 5` and `1.4x`, the directories do not overlap, and a higher setting does not help until you find what runs them in series.
- **Step time by type** gives the target. `init` at the top points to the provider cache, `run(...)` steps to your own workflow steps, and `plan`, with all else small, to state size.
- In **Step time by dirspace**, `NO CHANGES` marks a directory that planned and found no change. That time is waste: see [Run fewer dirspaces](#run-fewer-dirspaces).
- **API time** is latency to the Orchestration server, not your configuration. If it is a large share, tell support.
- **Signals** name settings to change, based on what the run did.

The profiler shows a plain duration only when the log proves it. Steps in one directory run back to back, so the time between two starts is the exact cost of the first. When the log cannot prove an end, the profiler marks the number, and does not guess. The `measurement` line counts the marks:

- `<`: at most
- `>`: at least
- `?`: the end is unknown

### Ask an LLM what to change

An LLM can map the profile and your configuration to the fixes on this page. This prompt works well:

```text
You are optimizing a Stategraph Orchestration run. I will give you:

1. The output of terrateam-run-profile.py for a slow run. It reports the run's
   phases, step time by type and by dirspace, server API time, and signals.
2. My .stategraph/config.yml.

Use these sources, and only these, for what the configuration actually supports.
The JSON Schema is the authority; where prose and schema disagree, the schema wins.

- https://raw.githubusercontent.com/stategraph/stategraph/main/api_schemas/terrat/config-schema.json
    The config JSON Schema. Every valid key, its type, and its default.
    Most objects set additionalProperties:false, so an unknown key is an error.
- https://stategraph.com/docs/orchestration/workflows/performance       (this tuning guide)
- https://stategraph.com/docs/reference/orchestration/configuration     (config reference prose)
- https://github.com/terrateamio/action                   (the runner: how steps execute)
- https://github.com/stategraph/stategraph                (the server)

Produce:
- A ranked list of changes, each with the seconds it should save, taken from the
  profile's own numbers rather than guessed. Say when you cannot estimate one.
- Attribute every second to a phase from "WHERE THE WALL CLOCK WENT", so it is
  clear whether a change targets startup, hooks, the dirspace steps, or the
  server API.
- The exact YAML diff for each change.
- The risk of each change and how to verify it did not break anything.
- Anything the profile suggests is NOT a configuration problem
  (runner sizing, a slow third-party tool, provider API latency, repository
  size) stated plainly as such.

Rules:
- Validate every key you propose against the JSON Schema before you emit it.
  Cite its schema path and the default it declares, for example
  definitions/version-1/properties/parallel_runs, default 3.
- If a key is not in the schema, do not propose it. Say it does not exist.
- One change per branch, so each saving is attributable.
- Ranked by seconds saved, not by how easy the change is.

<paste the profiler output and your config.yml here>
```

The LLM adds the ranking and the YAML. The profiler already did the diagnosis.

The schema constrains the model. Orchestration validates your configuration against this file, so a key that is not in it does not exist, whatever the model says. If your model cannot fetch URLs, download the schema and paste it with your configuration:

```bash
curl -sO https://raw.githubusercontent.com/stategraph/stategraph/main/api_schemas/terrat/config-schema.json
```

### Terragrunt is opaque by default

If `init` or `plan` is slow under Terragrunt and the log does not say why, set both variables and run again. The output is long, but it shows each dependency resolution and each provider call.

```yaml
hooks:
  all:
    pre:
      - type: env
        name: TG_LOG_LEVEL
        cmd: ["echo", "debug"]
      - type: env
        name: TF_LOG
        cmd: ["echo", "DEBUG"]
```

## Cut the fixed startup cost

Before it plans a directory, each CI run (a GitHub Actions run, or a pipeline on GitLab) pays for the queue, the action image, and the checkout. On a small change, this fixed cost can be most of the run.

- The tree builder, config builder, and indexer are separate work manifests that run before your plan.
- With the default [`merge_steps`](#merge_steps), the ones that fire share one run where they can. The plan starts another run after it.
- With `merge_steps: none`, each one is another run that pays this cost again, in series.
- The profiler covers only the runner step, so it cannot see this cost. Read it from the job timings in GitHub Actions or GitLab CI.

### Do not rebuild the action image on every run

On GitHub Actions, the runner is a Docker container action. Its `action.yml` sets `image: 'Dockerfile'`, so with `uses: terrateamio/action@v1`, GitHub builds the image from source on every run, in every repository, for every job. The same image is published prebuilt:

```text
ghcr.io/terrateamio/action:v1
```

A pull of the prebuilt image, in place of the build, is reported to save 30 to 45 seconds per run. The edit depends on your workflow file, so compare the job timings before and after to confirm the saving.

!!! note "Reusable workflows"
    If you use [reusable workflows](/docs/orchestration/workflows/advanced/github-reusable-workflows), make this change once in the shared workflow, and every repository gets it.

### Cache the image on self-hosted runners

With Actions Runner Controller, start each job as a container and cache the images on the node, so that each job does not pull them again. This is reported to save 5 to 15 seconds more per run. On a self-managed GitLab runner, get the same saving: let the executor use an image already on the host, in place of a pull for each job.

The lowest startup cost comes from a long-lived self-hosted runner on a VM that stays up between runs. It removes all queue and provisioning time, but the runner is no longer ephemeral. This matters if you need a clean environment for each run, for isolation.

!!! tip "Compounding"
    An always-on runner also keeps a provider plugin cache warm between runs, not only within one run. The two changes add up.

### Watch the checkout on a large repository

`actions/checkout` on GitHub, and the repository clone on GitLab CI, fetch your whole repository, not only the directories in the plan. In a large monorepo, this takes real time, and the profiler never shows it. If the job timings show much time in checkout, the cause is repository size, not configuration, and the fixes are in your workflow file or `.gitlab-ci.yml`.

## Run fewer dirspaces

Runtime scales with the number of dirspaces in the operation. Before you make each dirspace faster, make sure that each one needs to run.

To see what Orchestration expects to run, comment `stategraph repo-config` on a pull request. The reply is the fully evaluated configuration, with anything that a config builder or the indexer generated.

### Shared files that fan out

When a shared file (a provider definition, a common parent, a root variable file) is in the `file_patterns` of every directory, a change to it triggers every directory. This is the most common cause of a run that is ten times larger than the change.

Decide what a shared file must trigger, then narrow the pattern:

```yaml
dirs:
  live/dev/lambda:
    when_modified:
      file_patterns:
        - "${DIR}/terragrunt.hcl"
        - "${DIR}/*.tf"
        - "${DIR}/*.tfvars"
```

For the full pattern syntax, including `!` exclusions, see [when_modified](/docs/reference/orchestration/configuration/when-modified).

### Directories that should never run on their own

Module directories, templates, and scratch directories should not be dirspaces. Give them an empty pattern list:

```yaml
dirs:
  modules:
    when_modified:
      file_patterns: []
```

See [Ignoring a directory](/docs/reference/orchestration/configuration/ignore-patterns).

### Dependencies that pull in unchanged directories

By default, when a dependency changes, each directory that depends on it joins the run, even with no changes of its own. To keep a directory in the layer order but run it only when it changes, use `prune_on_no_change`:

```yaml
dirs:
  database:
    when_modified:
      depends_on:
        tag_query: 'dir:network'
        prune_on_no_change: true
      file_patterns: ["${DIR}/*.tf"]
```

`depends_on` also makes directories run in series: a dependent directory starts only after its dependency finishes. A dependency that you do not need costs you extra dirspaces and lost concurrency.

### The indexer: a trade-off

If you keep `file_patterns` by hand so that a module change triggers its consumers, the [indexer](/docs/reference/orchestration/configuration/indexer) does this for you. It maps `module` blocks and symlinks, marks module directories as not runnable on their own, and marks the directories that use them as runnable.

```yaml
indexer:
  enabled: true
```

The indexer has a cost, with a limit:

- Indexing is its own work manifest, like plan and apply. With the default `merge_steps`, it is a separate CI run, and your plan waits for it. You pay the full fixed startup cost a second time, in series, before the run that you want.
- Orchestration stores the index for the commit, so it builds the index once per commit, not once per operation. A new plan on the same SHA uses the stored index, and only the first operation on a new commit waits.

Decide on your own numbers:

| Enable it when | Skip it when |
| --- | --- |
| Hand-written patterns are missing module consumers, so changes ship unplanned | Your patterns are already tight and correct |
| A shared module change over-triggers because patterns are broad and defensive | Profiles show few dirspaces and a large fixed startup cost |
| You have enough directories that a wrong dirspace set costs minutes | One extra serialized job is a large share of your total run |

The indexer is worth it when the dirspaces that it removes cost more than the extra run that it adds. Profile before and after, and compare the `WHERE THE WALL CLOCK WENT` totals for the whole pull request, not for one job.

## Run dirspaces concurrently

### parallel_runs

`parallel_runs` sets how many dirspaces run at the same time in one CI job. The default is 3.

```yaml
parallel_runs: 5
```

`init` runs in series, and `plan` does not. The runner wraps each `init` in a `flock`, so that concurrent inits cannot corrupt a shared provider plugin cache. Then the plans run at `parallel_runs` concurrency. With four directories and `parallel_runs: 4`, the four inits run one after another, and then the four plans run side by side.

A higher `parallel_runs` makes the plans and the steps around them faster, but not `init`. If `init` takes most of the run, use a [shared provider cache](#share-a-provider-plugin-cache).

Raise the value in small steps, and watch the CPU, memory, and disk of the runner. Past some point, more concurrency makes the run slower. That point depends on the runner size and on your plans, so measure it. See [parallel_runs](/docs/reference/orchestration/configuration/parallel-runs).

### batch_runs

`parallel_runs` is limited to one job on one runner. `batch_runs` splits the operation across more than one CI job, and the jobs can run on separate runners. On GitLab, each of those jobs runs in its own pipeline:

```yaml
parallel_runs: 10
batch_runs:
  enabled: true
  max_workspaces_per_batch: 50
```

With `batch_runs` enabled, workspaces beyond `max_workspaces_per_batch` go into more work manifests.

!!! note "Concurrency"
    Orchestration limits the runs of one operation with `work_manifests.concurrent_runs`, which is `10` by default. A change to 100 workspaces with `max_workspaces_per_batch: 1` makes 100 work manifests, and with the default `max_work_manifests_per_node: 9` they take `ceil(100 / 9) = 12` runs — so the `concurrent_runs` default of `10` binds first, and the operation runs `10` at a time until they are done. Each run is a separate container with its own filesystem, so each one downloads its own providers. Set `max_workspaces_per_batch` high enough that each work manifest is worth its own setup.

See [batch_runs](/docs/reference/orchestration/configuration/batch-runs).

### `merge_steps`

`max_workspaces_per_batch` splits an operation into more work manifests. `merge_steps` puts the steps of one operation into fewer runs, because each extra run pays for its own checkout, provider download, and queue wait.

```yaml
batch_runs:
  merge_steps: setup_and_plan
```

`merge_steps` names the steps that can join a run that is already in progress. A step that it does not name always starts its own run. Four of its values name the highest step that can join.

| Value | Steps that may join a run |
|-------|---------------------------|
| `none` | Nothing joins. Every step gets its own run. |
| `setup` | Tree builder, config builder, and the indexer. The default. |
| `setup_and_plan` | The above, plus a plan. |
| `all` | The above, plus an apply, so a stack of layers can share one run while the job's work manifests fit `max_work_manifests_per_node`. |
| `by_phase` | Everything, but setup work (tree builder, config builder, indexer) and layer work (plan and apply) never share a run. |

Joining is best effort. A step joins a run only when the run is still queued or starting, when it has the same environment, the same `runs_on`, and the same head commit, and when it has been given fewer work manifests than `max_work_manifests_per_node`. A step that cannot join gets its own run. So a higher `merge_steps` never breaks an operation. At worst, it saves no run.

Two rules to know:

- `enabled` does not gate `merge_steps` or `max_work_manifests_per_node`. `enabled` gates only `max_workspaces_per_batch`, so both apply also with `batch_runs` off.
- Orchestration reads `merge_steps` from the config file in the repository, never from a generated config. The tree builder, config builder, and indexer run before a generated config exists, so a config builder cannot set it.

When to use each value:

- `all`: your operation is a deep stack of layers, and the cost is the overhead of each run, not the plan.
- `none`: you want each step on its own runner, for example to read its logs separately.
- `by_phase`: you want the stack of layers in one run, as with `all`, but the setup work in its own run. For example, to read the setup logs separately, or to keep a slow indexer from holding the plan of the first layer.

Example: a pull request has the three setup steps and three layers, and the first two layers have no changes. It takes:

- 6 runs with `none`.
- 4 runs with `setup`.
- 1 run with `setup_and_plan` or `all`.
- 2 runs with `by_phase`.

`merge_steps` changes only how many runs hold the work. It never changes what runs, or in what order.

### Runner size and routing

Larger runners help more when `parallel_runs` is above the default, because concurrent plans compete for CPU and disk. Use [runs_on](/docs/orchestration/workflows/advanced/runs-on) to send heavy workflows to a larger pool:

```yaml
workflows:
  - tag_query: "production"
    runs_on: [self-hosted, linux, x64, large]
```

On GitLab, Orchestration passes the `runs_on` values to the pipeline as runner tags. List the tags of the runners that you want, for example `runs_on: [large]`.

## Make each dirspace cheaper

### Share a provider plugin cache

By default, each dirspace installs providers into its own `.terraform` directory, so an operation over N dirspaces downloads the same provider N times. To share one cache, add an `all.pre` hook:

```yaml
hooks:
  all:
    pre:
      - type: env
        name: TF_PLUGIN_CACHE_DIR
        cmd: ["bash", "-c", "mkdir -p /tmp/tf-plugin-cache && echo /tmp/tf-plugin-cache"]
```

This is safe, because the runner already runs `init` in series.

Measured on `terraform` 1.5.7 with `hashicorp/aws` 5.31.0, `random` 3.6.0, and `null` 3.2.2 (96 MB of downloads, 381 MB installed):

| Scenario | Without cache | With cache |
| --- | --- | --- |
| 3 dirspaces, sequential `init` | 34.9 s, 288 MB downloaded | 19.4 s, 96 MB downloaded |
| 4 dirspaces at `parallel_runs: 3` | 47 to 52 s, 1523 MB on disk | about 24 s, 382 MB on disk |

`tofu` 1.6.3 and 1.9.0 show the same pattern.

!!! warning "Commit your lock files"
    The time saving applies only to a directory with a committed `.terraform.lock.hcl`. Without one, Terraform and OpenTofu download the provider again even when it is in the cache. They have no recorded hash to check it against.

    Four dirspaces with no lock file took 36.9 s without the cache and 39.0 s with it: no gain. Disk use still went from 1523 MB to 381 MB.

    If you cannot commit lock files, `TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE=true` lets Terraform use the cache anyway. HashiCorp documents this as an exceptional measure: the lock file that it writes has checksums for the current architecture only, so it is not portable across platforms.

On self-hosted ephemeral runners, the pod is deleted after each run. Each run then downloads the providers again through your NAT gateway, which adds to your cloud bill and your plan times.

- Put the cache on a persistent volume (EBS, EFS, or an equivalent), so that it stays between runs.
- A cache keyed on `GITHUB_RUN_ID` (`CI_JOB_ID` on GitLab) still helps across the dirspaces of one run. The first directory of each run pays the full price.

### Drop a redundant validate step

A `terraform validate` or `terragrunt validate` step before `plan` usually adds only time. `plan` finds the same configuration errors, so in CI `validate` gives nothing, and it costs a full tool invocation in each dirspace. In one Terragrunt repository, the `validate` step took 14 s per dirspace, against a 17 s plan: the run took almost twice as long.

Run `validate` in a pre-commit hook or a local check, and remove it from the workflow:

```yaml
workflows:
  - tag_query: ""
    plan:
      - type: init
      - type: plan
        extra_args: ["-input=false"]
```

### Skip workspace selection if you only use default

After `init`, the runner runs `workspace select`, and `workspace new` if the select fails. If you keep environments apart by directory, not by Terraform workspace, this is one wasted tool invocation per dirspace. Under Terragrunt, it costs more, because each invocation walks the full dependency graph.

```yaml
dirs:
  live/dev/lambda:
    create_and_select_workspace: false
```

See [dirs](/docs/reference/orchestration/configuration/dirs).

If the bundled Terragrunt config builder generates your `dirs` entries, set it for all generated entries at once:

```yaml
config_builder:
  enabled: true
  script: terragrunt-config-builder --no-create-and-select-workspace
```

!!! warning "Only with the default workspace"
    Do this only if you use the `default` workspace everywhere. If a directory uses a named workspace, this setting runs it against the wrong state, with no warning.

### Terragrunt: fetch dependency outputs from state

On a large dependency graph, Terragrunt resolves each `dependency` block with `tofu output` (or `terraform output`) on that dependency: a separate process per dependency, per unit. To read the state file directly, set:

```yaml
hooks:
  all:
    pre:
      - type: env
        name: TG_DEPENDENCY_FETCH_OUTPUT_FROM_STATE
        cmd: ["echo", "true"]
```

On a Terragrunt monorepo, this is often the largest single saving.

!!! warning "Three constraints"
    - Only the S3 backend supports it.
    - It does not work with OpenTofu client-side state encryption, because the state file in S3 is encrypted before upload.
    - Pin your Terraform or OpenTofu version. The flag reads the state file schema directly, and that schema has no compatibility guarantee across versions.

### When the plan itself is the cost

If the profiler shows `plan` at the top, and `init` and your own steps are already small, the plan itself is the cost.

Plan time then follows the size of the state, not of the change. Terraform and OpenTofu load and evaluate the full state on each run. A directory with thousands of resources is slow even for a one-line change. None of the changes above fix this: the graph is too big. There are two ways out.

!!! danger "A split buys time, but does not scale"
    The usual answer is to split the state into smaller root modules. Smaller states plan faster, so this works, but not for long:

    - Each state keeps growing. In a year you have more states to split, and each split is harder.
    - Each round is a state-migration refactor, with `moved` blocks, migration risk, and a change to your module layout. You pay it again each time the infrastructure grows.
    - More states means more dirspaces, which brings you back to running fewer dirspaces and to concurrency.

    Split a state when it has grown to cover unrelated things. Do not split resources that change together only to make a plan finish faster.

!!! tip "Infrastructure as a Database removes the refactor"
    [Infrastructure as a Database](/docs/infrastructure-as-a-database) replaces the state file with a database:

    - A plan reads only the resources that the change reaches, not the full state.
    - Independent root modules can plan and apply at the same time against the same server.
    - The state stays whole, and you keep your module layout.
    - Plan time no longer follows the total state size, so the state can grow with no split.

To use Infrastructure as a Database for a repository, or for one workflow, set the `engine` key:

```yaml
engine:
  name: stategraph
```

You onboard each directory one time. For setup, see [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration).

!!! note "Measure it"
    Profile before and after, on your own state. The saving of a graph-aware plan depends on how much of the graph your changes reach. A change to most of the resources in a state still has most of the work to do.

## Audit your workflow steps

When `init` and `plan` are under control, the remaining time usually comes from your own steps. Each step in `workflows.plan` runs once per dirspace, so a 60-second security scan across 10 dirspaces is 10 minutes of wall clock.

### Do not regenerate the plan JSON

If a step needs the plan as JSON, and an earlier step already made it, use that file again. The runner gives the plan file path in [`$TERRATEAM_PLAN_FILE`](/docs/orchestration/configuration/environment-variables).

- Another `terraform show -json` only repeats work. A `terragrunt show -json` also walks the dependency graph again.
- A repeated `show` is easy to miss, because each one looks cheap. The profiler totals it across all dirspaces, where it no longer looks cheap.

### Check whether the tool actually parallelizes

A tool with an internal queue gets slower as you give it more concurrent work. A higher `parallel_runs` then makes it slower, not faster. If you see this, move the tool out of the plan path.

In one measured example:

- A scan took 76 s alone, and about 220 s per dirspace when three ran at the same time.
- Of 2010 s of total scan time, only about 760 s was real work. The rest was queue time.

### Move non-blocking tools out of the operation

Security scans, cost annotations, and AI summaries do not have to run inside the runner action. Run them as a separate GitHub Actions workflow, or as a separate job in your GitLab pipeline, on the same pull request. Plan feedback stays fast, and the tools still have access to the branch, the diff, and the plan artifacts. A tool that does not gate the apply can move.

## Next Steps

- [Terragrunt config builder](/docs/orchestration/workflows/advanced/terragrunt-config-builder): generate `dirs` entries for a Terragrunt repository.
- [runs_on](/docs/orchestration/workflows/advanced/runs-on): route workflows to specific runner pools.
- [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration): plan against a database, not a state file.
- [Support](/docs/support): what to send when you want help with a profile.
