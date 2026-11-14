---
title: when_modified
description: The when_modified key in .stategraph/config.yml sets file patterns, autoplan, autoapply, prechecks, and the depends_on order of directories.
order: 27
---


`when_modified` sets when Stategraph Orchestration plans and applies a directory: the changed files that count, automatic plan and apply, the order between directories, and prechecks. You can set it at three levels:

- Global: the top-level `when_modified`, for all directories.
- Directory: `dirs.<directory>.when_modified`, for one directory.
- Workspace: `dirs.<directory>.workspaces.<workspace>.when_modified`, for one workspace.

Each level takes the same keys, except `prechecks`, which is global only. The most specific level wins: workspace, then directory, then global. See [dirs](/docs/reference/orchestration/configuration/dirs#when-modified).

## Default Configuration

```yaml
when_modified:
  file_patterns: ["${DIR}/*.tf", "${DIR}/*.tfvars"]
  autoplan: true
  autoplan_draft_pr: true
  autoapply: false
  depends_on: ""
```

## Keys

| Key | Type | Description |
| --- | --- | --- |
| `file_patterns` | list | File globs that mark a change to the directory, relative to the root of the repository. Prefix a glob with `!` to exclude it. Default is `["${DIR}/*.tf", "${DIR}/*.tfvars"]`. In the global `when_modified`, a leading `**/` is treated as `${DIR}/`, and a leading `*` gets `${DIR}/` in front, also after `!`. So the schema form of the default, `["**/*.tf", "**/*.tfvars"]`, is the same. |
| `autoplan` | boolean | Plan automatically when a pull request opens or changes. Default is `true`. |
| `autoplan_draft_pr` | boolean | Plan automatically when a draft pull request opens or changes. Default is `true`. |
| `autoapply` | boolean | Apply automatically after the pull request merges. Default is `false`. |
| `depends_on` | string or object | The directories or workspaces that must plan and apply first. Use `dir:` for a path from the root of the repository, or `relative_dir:` for a path relative to this directory. Use `outputs:` or `relative_outputs:` to depend on the outputs of a directory. See [Depending on outputs](#depending-on-outputs). You can combine them with other [tag queries](/docs/reference/orchestration/configuration/tag-queries). Default is an empty string. The object form adds options such as `prune_on_no_change`. See [Depends-On](#depends-on). |
| `prechecks` | list | Cheap checks that decide, before any setup job runs, if a pull request needs any work. Global only. Default is an empty list. See [Prechecks](#prechecks). |

### Prechecks

Before Orchestration can tell if a pull request changes anything that it manages, autoplan normally must run the [tree builder](/docs/reference/orchestration/configuration/tree-builder), the [config builder](/docs/reference/orchestration/configuration/config-builder), and the [indexer](/docs/reference/orchestration/configuration/indexer). Each one costs a CI run on each pull request, also on pull requests that need no work.

`prechecks` gives Orchestration a hint, so it can answer sooner. Each check reads the static configuration in your repository and the pull request. If any check is false, Orchestration does nothing and starts no CI run.

```yaml
when_modified:
  prechecks:
    - user: ['!renovate[bot]']
    - file_patterns: ['!docs/**']
    - config_file_patterns:
        stale_config_min: 60
```

`prechecks` is valid only in the global `when_modified`. Under `dirs.<directory>.when_modified`, it is a configuration error: a precheck decides for the whole pull request, before any directory is known.

Orchestration reads prechecks only from the configuration committed to your repository. It ignores a `prechecks` list from the config builder, because a precheck decides if the config builder runs at all.

#### Checks

| Check | Description |
| --- | --- |
| `user` | A list of user names. The check passes when the user who opened the pull request matches the list. The pusher does not count. |
| `file_patterns` | A list of file globs. The check passes when a file that the pull request changes matches the list. The globs are repository paths, with no `${DIR}` prefix. |
| `config_file_patterns` | The check passes when a file that the pull request changes matches a directory in the configuration that Orchestration derived for the destination branch. `stale_config_min` sets how many minutes can pass since Orchestration last derived that configuration. |

#### Negation and the implicit `'*'`

`user` and `file_patterns` accept entries with a `!` prefix, which exclude instead of include:

- A list of only negations has an implicit `'*'`: it matches everything that the negations do not exclude.
- A mixed list has no implicit `'*'`: at least one positive entry must also match.
- An empty list matches nothing.

So `['!docs/**']` means "any change outside `docs/`", and `['infra/**', '!docs/**']` means "a change under `infra/` that is not under `docs/`".

#### When a check cannot answer

A check that cannot read the data it needs passes, and the usual evaluation continues:

- `config_file_patterns` passes when no configuration was derived for the destination branch yet, when the configuration is older than `stale_config_min`, or when the pull request changes the Orchestration configuration file. A `stale_config_min` of `0` makes each configuration stale, which turns the check off.
- `file_patterns` and `config_file_patterns` pass when the VCS truncates the list of changed files. Orchestration treats such a list as no answer, so a very large pull request is always evaluated normally.
- GitHub stops the list at 3000 files and does not report it, so the list can miss the file that a check looks for.

The age counts from the last time Orchestration derived the configuration, not the first. A pull request that falls through on a stale configuration derives it again, so the next pull request against that branch finds a fresh one. The check thus recovers by itself on a branch that nobody pushes to, at the cost of one full evaluation for the first pull request after the window.

A push to the default branch records a derived configuration, and so does the evaluation of any pull request against a branch. For a destination branch that nothing evaluated yet, `config_file_patterns` cannot answer, and the pull request is evaluated normally.

#### Which configuration the check reads

Orchestration reads the recent commits of the destination branch and keeps only the configurations derived at one of those commits. It uses the one derived at the commit nearest to the branch head.

A repository holds a derived configuration for each branch that Orchestration evaluated. The newest one can come from a branch that moved all the directories.

A configuration from a commit of the destination branch is a real earlier state of that branch, so it is safe to reuse. A force push or a rebase of the destination branch also cannot make the check read a configuration for a commit that is no longer on it.

Only recent commits are read, so a configuration derived far back in the history is not found. `stale_config_min` would reject it anyway.

#### Prechecks read the VCS diff

`file_patterns` and `config_file_patterns` use the list of changed files that the VCS reports for the pull request. This is what lets them answer before Orchestration does any work.

With the [tree builder](/docs/reference/orchestration/configuration/tree-builder), the rest of the evaluation uses a different list. The tree builder decides which files a pull request changes, and it can mark a file that the VCS diff does not list, for example a directory whose module dependency moved. A precheck cannot wait for that list, because the tree builder run is the CI run that the precheck skips.

So a precheck stops a pull request whose only relevant change is one that the tree builder would find. Write your patterns against the paths that the VCS reports.

#### Overriding a precheck

Prechecks apply only to autoplan. A `stategraph plan` comment runs the pull request regardless, and after that the prechecks no longer apply to later commits on it. The later layers of a layered run never read prechecks.

#### Prechecks and the apply check

A pull request that a precheck stopped must still be mergeable. Orchestration creates the completed `stategraph apply` commit status by default, so the pull request can merge. It did no work in this case. Set [`apply_requirements.create_completed_apply_check_on_noop`](/docs/reference/orchestration/configuration/apply-requirements) to `false` to skip the status.

### Depends-On

`depends_on` names the directories that a directory depends on. Use it when your infrastructure has functional layers that must deploy in order. For example, a network must apply before a managed PostgreSQL service that uses its outputs.

- Each layer plans and applies after the successful apply of the layer before it.
- A change in the lowest layer starts plans and applies that cascade through the dependent layers.

A top-level `depends_on` makes all directories depend on the directories that it names. For better control, set it per directory or per workspace, with `dirs.<directory>.when_modified.depends_on` or `dirs.<directory>.workspaces.<workspace>.when_modified.depends_on`.

A top-level `depends_on` also does not work with the [`stacks`](/docs/reference/orchestration/configuration/stacks) section. It applies to each directory, so it names directories outside the stack of the directory that carries it, which is an error. See [`depends_on` and Stacks](#depends_on-and-stacks).

#### `depends_on` and Stacks

A `depends_on` orders directories inside one stack. It cannot reach out of the stack it is written in.

With a [`stacks`](/docs/reference/orchestration/configuration/stacks) section, each directory that a `depends_on` names must be in the same stack as the directory that declares it, or in a stack that shares a nested stack with it. A `depends_on` into an unrelated stack is a configuration error, and the run reports it instead of planning.

Two directories share a stack when the paths to their stacks have a stack in common: the stack itself when both are in one stack, or a nested stack that holds both. To order two stacks that share nothing, use the `plan_after` or `apply_after` rule of the `stacks` section.

Without a `stacks` section, all directories are in the same stack.

#### Object form and `prune_on_no_change`

`depends_on` is a string (a tag query) or an object with these keys:

| Key | Type | Description |
| --- | --- | --- |
| `tag_query` | string | The dependency tag query, the same as the string form of `depends_on`. Required. |
| `prune_on_no_change` | boolean | When `true`, the dirspace stays in the layer order for the layers that depend on it, but runs only when it has changes of its own. Default is `false`. |

By default, a change in a dependency pulls the dirspace into the run, also when it has no changes of its own.

```yaml
dirs:
  database:
    when_modified:
      depends_on:
        tag_query: 'dir:network'
        prune_on_no_change: true
      file_patterns: ["${DIR}/*.tf"]
```

Here, `database` comes after `network` in the layer order, but it plans and applies only when `database` itself has changes. A change in `network` alone does not trigger it.

#### Depending on outputs

A `depends_on` tag query can name the outputs of a dependency, not only the dependency. The dirspace then runs only when the value that it names changed, not each time the dependency applies.

| Term | Meaning |
| --- | --- |
| `<path> in outputs:<dir>` | The value at `<path>` in the outputs of `<dir>` changed. |
| `outputs:<dir>` | Any output of `<dir>` changed. |
| `<path> in relative_outputs:<dir>` | The same as `outputs:`, with `<dir>` relative to the directory that declares the dependency, as with `relative_dir:`. |

```yaml
dirs:
  app/database:
    when_modified:
      file_patterns: ["${DIR}/*.tf"]
  app/web:
    when_modified:
      depends_on: 'db.host in outputs:app/database'
      file_patterns: ["${DIR}/*.tf"]
```

Here `app/web` comes after `app/database`, as with `dir:app/database`. The difference comes after the apply. If the apply of `app/database` left `db.host` at the value it had before, Orchestration removes `app/web` from the run, and its dependents too. If nothing is left to run, the pull request is complete and its checks close.

The path is a dotted path into the outputs of the dependency. Its first element is the output name. For the Terraform engines (`terraform`, `tofu`, `terragrunt`, `cdktf`), the comparison uses the `value` of the output. So `db.host` reads the `host` key of the output named `db`, and a change to only the `sensitive` or `type` field is not a change. For the `custom` engine, the path reads the JSON that the `outputs` command printed.

Orchestration compares values as JSON:

- The order of the keys of an object does not matter.
- The order of the items of a list matters.
- A path that does not exist reads as `null`. An output that is absent on one side and `null` on the other is not a change.

The comparison is always against the most recent successful apply of that dirspace in a **different** pull request, which is what the infrastructure holds now. A second apply in the same pull request also compares against that other pull request.

##### What always runs

- A dirspace whose own files changed always runs. Output pruning removes only a dirspace that is in the run through `depends_on`.
- Before the dependency applies in the pull request, `outputs:` has the same meaning as `dir:`, and `relative_outputs:` the same as `relative_dir:`. The dependent waits for its dependency, as it does without outputs.
- A plan with no changes counts as applied. It is not an apply and records no outputs, so the dependent runs.
- `prune_on_no_change` has priority. A dirspace that sets it is removed each time it has no changes of its own.

##### Bringing back a pruned dirspace

To bring back a pruned dirspace, comment an explicit plan that names it:

```text
stategraph plan dir:app/web
```

Add `workspace:<name>` to name one workspace of the directory. This reaches each dirspace that the pull request would run if nothing were pruned. It is the same mechanism as a scoped plan. The dirspace plans, and after the plan you can apply it. Its dependents follow the same rule: if its outputs do not change, they stay pruned, and another explicit plan brings back the next one. This way you can walk a pruned branch one dirspace at a time.

!!! warning "Dependencies without outputs"
    If the dependency records no outputs, nothing can change, and Orchestration prunes the dependent. This is the case for the engines that send no outputs (`pulumi` and `stategraph`), and when the [`outputs` configuration](/docs/reference/orchestration/configuration/engine#outputs) of the engine sets `collect: false`. Orchestration stores a value that it masks as a secret as `***`, so two different secrets compare equal. Use `dir:` instead of `outputs:` for a dependency whose outputs you cannot compare.

## Configuration Examples

### Same configuration at different levels

These three configurations give the same result for the `production` directory.

#### Global level

```yaml
when_modified:
  file_patterns: ["${DIR}/*.tf", "${DIR}/*.tfvars"]
  autoplan: true
  autoapply: false
```

#### Directory level

```yaml
dirs:
  production:
    when_modified:
      file_patterns: ["${DIR}/*.tf", "${DIR}/*.tfvars"]
      autoplan: true
      autoapply: false
```

#### Workspace level

```yaml
dirs:
  production:
    workspaces:
      default:
        when_modified:
          file_patterns: ["${DIR}/*.tf", "${DIR}/*.tfvars"]
          autoplan: true
          autoapply: false
```

### Autoplan on Terraform file changes

```yaml
when_modified:
  file_patterns: ["${DIR}/*.tf"]
  autoplan: true
  autoplan_draft_pr: false
  autoapply: false
```

A change to any `.tf` file in the repository starts a plan. Draft pull requests get no plan, and nothing applies after the merge.

### Autoplan and autoapply on Terraform and tfvars file changes

```yaml
when_modified:
  file_patterns: ["${DIR}/*.tf", "${DIR}/*.tfvars"]
  autoplan: true
  autoplan_draft_pr: true
  autoapply: true
```

A change to a `.tf` or `.tfvars` file starts a plan, also in draft pull requests. After the merge, the changes apply automatically, and a status check shows the pending applies.

### Exclude files from autoplan

```yaml
when_modified:
  file_patterns: ["${DIR}/*.tf", "!**/modules/**/*.tf"]
  autoplan: true
  autoplan_draft_pr: true
  autoapply: false
```

A change to a `.tf` file starts a plan, also in draft pull requests, except for `.tf` files in the `modules` directory and its subdirectories.

### Autoplan with one dependency

```yaml
dirs:
  "database/":
    when_modified:
      depends_on: "relative_dir:../base"
```

A change in the `base` directory starts a plan for the `database` directory.

### Layers of dependencies

```yaml
dirs:
  network:
    when_modified:
      file_patterns: ["${DIR}/*.tf"]
  database:
    when_modified:
      depends_on: 'dir:network'
      file_patterns: ["${DIR}/*.tf"]
  application:
    when_modified:
      depends_on: 'dir:database'
      file_patterns: ["${DIR}/*.tf"]
```

A change in `network` starts a plan for the `network` layer. If its apply succeeds, the `database` layer, which depends on `network`, plans next. If that apply succeeds, the `application` layer plans, and so on.

!!! note "Locks and layered runs"
    An apply acquires a lock, whether it succeeds or fails. After one dirspace applies in a pull request, that pull request holds the locks on all the dirspaces that it targets. Only a successful apply and merge releases a lock. To force the release, comment `stategraph unlock` on the pull request.

## Related

- [dirs](/docs/reference/orchestration/configuration/dirs)
- [Ignoring a directory](/docs/reference/orchestration/configuration/ignore-patterns)
- [stacks](/docs/reference/orchestration/configuration/stacks)
- [Layered runs](/docs/orchestration/workflows/advanced/layered-runs)
- [Lock management](/docs/orchestration/workflows/advanced/lock-management)
