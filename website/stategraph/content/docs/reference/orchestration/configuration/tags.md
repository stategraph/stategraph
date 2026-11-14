---
title: tags
description: Reference for the top-level tags key in .stategraph/config.yml. Derive dest_branch and branch tags from branch names with Lua patterns.
order: 24
---


The top-level `tags` key defines dynamic tags from the branches of a pull request: `dest_branch` tags from the destination branch, and `branch` tags from the source branch. Stategraph Orchestration adds them to each directory, so that [tag queries](/docs/reference/orchestration/configuration/tag-queries) in workflows and access control can adapt to the branch. Static tags for specific directories go under the [`dirs`](/docs/reference/orchestration/configuration/dirs) key. You can combine both kinds in one tag query.

## Default Configuration

```yaml
tags: {}
```

## Keys

| Key | Type | Description |
| --- | --- | --- |
| `dest_branch` | map | Tags for destination branches. The key is the tag value. The value is a [Lua pattern](https://www.lua.org/manual/5.4/manual.html#6.4.1) that Orchestration matches against the destination branch name. Produces `dest_branch:<key>` tags. |
| `branch` | map | Tags for source branches. The key is the tag value. The value is a Lua pattern that Orchestration matches against the source branch name of the pull request. Produces `branch:<key>` tags. |

## Example Configuration

```yaml
tags:
  dest_branch:
    main: '^main$'
    staging: '^staging$'
    dev: '^dev$'
dirs:
  dev:
    tags: [dev]
  staging:
    tags: [staging]
  prod:
    tags: [prod]
```

The `dest_branch` tag has three values: `main`, `staging`, and `dev`. Each value has a pattern that matches the branch of the same name. The `dirs` section sets static tags on three directories.

Source branch tags work the same way under `branch`:

```yaml
tags:
  branch:
    hotfix: '^hotfix/'
    feature: '^feature/'
```

A pull request from the branch `hotfix/db-timeout` gets the `branch:hotfix` tag.

## Using Tags in Tag Queries

```yaml
workflows:
  - tag_query: 'dest_branch:main'
    plan:
      - type: env
        name: ENVIRONMENT
        cmd: ['echo', 'main']
      - type: init
      - type: plan
    apply:
      - type: env
        name: ENVIRONMENT
        cmd: ['echo', 'main']
      - type: init
      - type: apply
```

This workflow runs when the `dest_branch` tag has the value `main`. To make a workflow more specific, combine the tag with tags from the `dirs` section.

## Matching Branch Names with Patterns

Orchestration matches branch names with [Lua patterns](https://www.lua.org/manual/5.4/manual.html#6.4.1). For simple cases, Lua patterns are like regular expressions:

- `^` anchors the start, and `$` anchors the end. `'^main$'` matches only the string `main`.
- `.` matches any character, and `*` repeats.
- There is no alternation (`|`) and no `\d`-style class. Use `%d` and the other Lua classes.

Change the patterns to match your branch names. For example, `'^release/'` matches every branch under `release/`.

## Related

- [Tag queries](/docs/reference/orchestration/configuration/tag-queries)
- [dirs](/docs/reference/orchestration/configuration/dirs)
- [Tag system](/docs/orchestration/workflows/advanced/tag-system)
- [Gitflow](/docs/orchestration/workflows/advanced/gitflow)
