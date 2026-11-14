---
title: Tag Queries
description: Reference for tag queries in .stategraph/config.yml. Define tags, combine them with and, or, not, and in, and target workflows and commands.
order: 23
---


A tag query selects directories and workspaces by their tags. You tag directories by criteria such as environment, application, or region. Stategraph Orchestration then uses tag queries to decide:

- Which workflows apply to which directories.
- Who has access to specific directories.
- How apply requirements are enforced.

## Defining Tags

Tags come from two places:

- Top-level tags: dynamic tags from criteria like the destination branch of a pull request.
- Directory-level tags: static tags on specific directories of your repository.

### Top-Level Tags

The top-level `tags` key in `.stategraph/config.yml` defines dynamic tags. With them, workflows adapt to the context of your pull requests and branches. For example:

```yaml
tags:
  dest_branch:
    main: '^main$'
    staging: '^staging$'
    dev: '^dev$'
```

The `dest_branch` tag has three values: `main`, `staging`, and `dev`. Each value has a [Lua pattern](https://www.lua.org/manual/5.4/manual.html#6.4.1) that matches the destination branch name. The `tags.branch` key defines `branch:<value>` tags from the source branch name in the same way. See the [tags reference](/docs/reference/orchestration/configuration/tags).

### Directory-Level Tags

The `dirs` section of your [configuration](/docs/orchestration/configuration) assigns static tags to specific directories:

```yaml
dirs:
  dev:
    tags: [dev]
  staging:
    tags: [staging]
  prod:
    tags: [prod]
```

The `dev`, `staging`, and `prod` directories get the tags `dev`, `staging`, and `prod`.

## Tag Query Syntax

A tag query is a boolean expression over tags. Orchestration supports these operators:

- `and`: matches directories that have all the specified tags. This is the default operator.
- `or`: matches directories that have at least one of the specified tags.
- `not`: matches directories that do not have the specified tag.
- `in`: `<path> in dir` matches directories whose path contains `<path>` as whole path components, like the glob `**/<path>/**`. Glob characters in `<path>` are not wildcards. The right-hand side also accepts `outputs:<dir>` and `relative_outputs:<dir>`, which match a directory whose outputs changed. These two forms have a meaning only inside [`depends_on`](/docs/reference/orchestration/configuration/when-modified#depending-on-outputs).
- Parentheses: group and prioritize expressions.

| Tag query expression | Description |
| --- | --- |
| `prod and api` | Matches directories with both the `prod` and the `api` tag. |
| `staging or dev` | Matches directories with the `staging` or the `dev` tag. |
| `not deprecated` | Matches directories without the `deprecated` tag. |
| `app in dir` | Matches directories that have an `app` component in their path. |
| `(web or api) and prod` | Matches directories with the `web` or the `api` tag, and also the `prod` tag. |
| `dir:app or dir:database` | Matches the `app` directory and the `database` directory. |
| `outputs:app/database` | In a `depends_on`, matches the `app/database` directory when any of its outputs changed. |
| `db.host in outputs:app/database` | In a `depends_on`, matches the `app/database` directory when the value at `db.host` in its outputs changed. |
| `relative_outputs:../database` | The same as `outputs:`, with the directory relative to the directory that declares the dependency. |

Because `and` is the default operator, a space between two terms means that both must be true of the same directory. A directory is only one directory, so a query like `dir:app dir:database` matches nothing. To select several directories, join them with `or`.

`and` binds more tightly than `or`, written out or implied. `prod api or dev` means `(prod and api) or dev`, the same as `prod and api or dev`. Use parentheses for the other grouping.

This matters most in a long list of directories:

- A single missing `or` turns two entries into one `and` that never matches.
- Those two directories drop out of the run, and the rest still run.
- For a `stategraph plan` or `stategraph apply` comment, Orchestration then posts a comment that lists the directories it left out, and the command with `or` added.

## Using Tag Queries

### Workflows

In the `workflows` section of your [configuration](/docs/orchestration/configuration), a tag query selects the directories of a workflow. In this example, the first workflow runs for the `main` branch and the `prod` environment. The second runs for the `staging` branch and the `staging` environment.

```yaml
workflows:
  - tag_query: 'dest_branch:main and prod'
    plan:
      - type: init
      - type: plan
    apply:
      - type: init
      - type: apply
  - tag_query: 'dest_branch:staging and staging'
    plan:
      - type: init
      - type: plan
    apply:
      - type: init
      - type: apply
```

### Commands

In a pull request comment, a tag query limits a plan or an apply to the directories that it matches:

```text
stategraph plan <tag-query>
```

```text
stategraph apply <tag-query>
```

For advanced tag queries, see the [tag system](/docs/orchestration/workflows/advanced/tag-system) guide.

## Related

- [tags](/docs/reference/orchestration/configuration/tags)
- [dirs](/docs/reference/orchestration/configuration/dirs)
- [workflows](/docs/reference/orchestration/configuration/workflows)
- [stategraph plan](/docs/reference/orchestration/commands/plan)
- [stategraph apply](/docs/reference/orchestration/commands/apply)
