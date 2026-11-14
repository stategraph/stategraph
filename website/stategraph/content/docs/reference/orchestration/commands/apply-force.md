---
title: stategraph apply-force
description: Run an apply from a pull request comment even when the apply requirements are not met, without Gatekeeper gates, as a trusted user.
order: 5
---


`stategraph apply-force` is a pull request comment, not a terminal command: it runs an apply even when the pull request does not meet its [apply requirements](/docs/reference/orchestration/configuration/apply-requirements). It also bypasses [Gatekeeper](/docs/orchestration/governance/gatekeeper) gates: Orchestration does not check them and requests no gate approval.

With [access control](/docs/reference/orchestration/configuration/access-control), only the users in the `apply_force` list of a policy can run it. By default, the list is empty.

!!! warning "Trusted users only"
    Use `apply-force` only when necessary, and restrict it to trusted users. Every force apply is logged for audit.

## Usage

```text
stategraph [name=value ...] apply-force [tag-query]
```

A [tag query](/docs/reference/orchestration/configuration/tag-queries) filters by `dir:<path>`, `workspace:<name>`, or tag name, with `and`, `or`, and `not`.

## Parameters

A comment sets a parameter as a `name=value` token before the verb:

```text
stategraph mode=DEBUG apply-force dir:staging
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
stategraph apply-force
```

A specific directory:

```text
stategraph apply-force dir:hotfix
```

Production changes:

```text
stategraph apply-force production
```

A complex query:

```text
stategraph apply-force dir:critical and workspace:prod
```

## Related commands

- [stategraph apply](/docs/reference/orchestration/commands/apply): the standard apply with requirements
- [stategraph gate approve](/docs/reference/orchestration/commands/gate-approve): approve validation gates instead of skipping them
