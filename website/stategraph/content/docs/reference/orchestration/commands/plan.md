---
title: stategraph plan
description: Run the plan workflow from a pull request comment, for every changed directory, or only for the directories that match a tag query.
order: 2
---


`stategraph plan` is a pull request comment, not a terminal command: it runs a plan to preview infrastructure changes before an apply.

- The plan runs the [workflow](/docs/reference/orchestration/configuration/workflows) in `.stategraph/config.yml`.
- Orchestration stores the plan files for the later apply. [storage](/docs/reference/orchestration/configuration/storage) sets where.
- With [access control](/docs/reference/orchestration/configuration/access-control), the `plan` list of a policy sets who can run it. By default, everyone can.

## Usage

```text
stategraph [name=value ...] plan [tag-query]
```

Without a tag query, the command plans every changed directory. A [tag query](/docs/reference/orchestration/configuration/tag-queries) filters by `dir:<path>`, `workspace:<name>`, or tag name, with `and`, `or`, and `not`.

When the tag query has only `dir:` and `workspace:` tags and no `not`, Orchestration plans the named directories again, even when their previous plan found no changes.

## Parameters

A comment sets a parameter as a `name=value` token before the verb:

```text
stategraph mode=DEBUG plan dir:staging
```

A parameter is a name declared under `parameters.names` in `.stategraph/config.yml`, and its value is one of the `values` of that name. Orchestration passes each parameter to the run as an environment variable, with the name unchanged.

An alias name replaces the verb, and takes the arguments of the action it maps to:

```text
stategraph debug dir:staging
```

The configuration is the administrator's. An undeclared name, or a value outside `values`, posts an error comment and starts no run.

See [parameters](/docs/reference/orchestration/configuration/parameters) for the configuration.

## Examples

All changes:

```text
stategraph plan
```

A specific directory:

```text
stategraph plan dir:staging
```

A specific workspace:

```text
stategraph plan workspace:production
```

Multiple directories:

```text
stategraph plan dir:app or dir:database
```

A complex tag query:

```text
stategraph plan production and dir:us-east-1
```

## Related commands

- [stategraph apply](/docs/reference/orchestration/commands/apply): apply the planned changes
