---
title: stategraph apply
description: Apply the stored plans of a pull request from a comment, for every planned directory, or only for the directories that match a tag query.
order: 3
---


`stategraph apply` is a pull request comment, not a terminal command: it applies the planned changes to your infrastructure. It runs the [workflow](/docs/reference/orchestration/configuration/workflows) in `.stategraph/config.yml`.

## Prerequisites

- A successful plan, automatic or from `stategraph plan`, has run first.
- The pull request meets the [apply requirements](/docs/reference/orchestration/configuration/apply-requirements), unless you use `apply-force`.
- You have apply permission. With [access control](/docs/reference/orchestration/configuration/access-control), the `apply` list of a policy sets who can apply. By default, everyone can.

## Usage

```text
stategraph [name=value ...] apply [tag-query]
```

Without a tag query, the command applies every stored plan. A [tag query](/docs/reference/orchestration/configuration/tag-queries) filters by `dir:<path>`, `workspace:<name>`, or tag name, with `and`, `or`, and `not`.

## Parameters

A comment sets a parameter as a `name=value` token before the verb:

```text
stategraph mode=DEBUG apply dir:staging
```

A parameter is a name declared under `parameters.names` in `.stategraph/config.yml`, and its value is one of the `values` of that name. Orchestration passes each parameter to the run as an environment variable, with the name unchanged.

An alias name replaces the verb, and takes the arguments of the action it maps to:

```text
stategraph debug dir:staging
```

The configuration is the administrator's. An undeclared name, or a value outside `values`, posts an error comment and starts no run.

See [parameters](/docs/reference/orchestration/configuration/parameters) for the configuration.

## Examples

All plans:

```text
stategraph apply
```

A specific directory:

```text
stategraph apply dir:staging
```

A specific workspace:

```text
stategraph apply workspace:production
```

Multiple directories:

```text
stategraph apply dir:app or dir:database
```

A complex tag query:

```text
stategraph apply production and dir:us-east-1
```

## Related commands

- [stategraph plan](/docs/reference/orchestration/commands/plan): create a plan before applying
- [stategraph apply-force](/docs/reference/orchestration/commands/apply-force): apply without meeting the requirements
