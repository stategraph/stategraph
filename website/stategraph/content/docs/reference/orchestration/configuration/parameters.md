---
title: parameters
description: Reference for the parameters key in .stategraph/config.yml. Declare the parameter names a comment may set, and the aliases that bundle them.
order: 20
---

`parameters` declares the parameter names that a pull request comment can set on a run, and the aliases that bundle parameters into a custom command. You declare parameters in `.stategraph/config.yml`.

The configuration is yours as the administrator. A comment cannot set a parameter name that your configuration does not declare, and cannot set a value that the name does not accept.

## Syntax

```yaml
parameters:
  names:
    mode:
      values: ['DEBUG', 'NORMAL']
      fail_if_set: true
    region:
      values: ['us-east-1', 'eu-west-1']
  aliases:
    debug:
      action: plan
      params:
        mode: 'DEBUG'
```

## Keys

| Key | Type | Description |
| --- | --- | --- |
| `names` | object | A parameter name as the key, and as the value an object with `values` and `fail_if_set`. |
| `aliases` | object | An alias name as the key, and as the value an object with `action` and `params`. |

### Names

| Key | Type | Description |
| --- | --- | --- |
| `values` | array of strings, or null | The values that the parameter accepts. Absent or null accepts any string. |
| `fail_if_set` | boolean | When `true`, a run that sets this parameter counts as failed after its work is done: its checks fail with the name of the parameter, and the directories count as needing a plan, so an apply does not run until a new plan. The layers after it do not run. Default is `false`. |

### Aliases

| Key | Type | Description |
| --- | --- | --- |
| `action` | string | The command that the alias runs: `plan`, `apply`, `apply-force`, or `apply-autoapprove`. |
| `params` | object | A parameter name as the key, and as the value the string that the alias sets. |

## Rules

A comment sets parameters as `name=value` tokens before the command:

```text
stategraph mode=DEBUG plan dir:staging
```

- A parameter is a name that you declare under `parameters.names`. Its value must be one of its `values` when `values` is present.
- An alias name replaces the command and takes the arguments of the action that it maps to, so `stategraph debug dev` is valid.
- An alias may not shadow a built-in command such as `plan` or `apply`.
- An undeclared name, or a value outside `values`, posts an error comment and starts no run.
- An alias takes no extra parameters. Set the parameters of an alias in its `params` configuration.

## How a parameter reaches a run

Stategraph Orchestration resolves the parameters when it evaluates the comment, stores them on the run, and passes each parameter to the run as an environment variable, with the name unchanged.

## Example configuration

```yaml
parameters:
  names:
    log_level:
      values: ['DEBUG', 'INFO']
      fail_if_set: true
  aliases:
    debug:
      action: plan
      params:
        log_level: 'DEBUG'
```

This configuration declares the parameter `log_level`, which accepts `DEBUG` or `INFO` and marks a run that sets it as failed, and the alias `debug`, which runs `plan` with `log_level` set to `DEBUG`.

## Related

- [stategraph plan](/docs/reference/orchestration/commands/plan)
- [tag query syntax](/docs/reference/orchestration/configuration/tag-queries)
