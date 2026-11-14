---
title: stacks
description: Reference for the stacks key in .stategraph/config.yml. Group dirspaces into named stacks with shared variables and ordering rules.
order: 21
---


The top-level `stacks` key groups dirspaces (directory and workspace combinations) into named stacks, each with shared variables and Stategraph Orchestration rules.

## Default Configuration

```yaml
stacks:
  names: {}
```

## Keys

### `stacks`

| Key | Type | Description |
| --- | --- | --- |
| `names` | map | A map of stack names to their configurations. |

### `stacks.names.<name>`

Each named stack is a regular stack, with `tag_query`, or a nested stack, with `stacks`.

| Key | Type | Description |
| --- | --- | --- |
| `tag_query` | string | Regular stack: required. The [tag query](/docs/reference/orchestration/configuration/tag-queries) that selects the dirspaces of the stack. |
| `stacks` | list | Nested stack: required. The names of the stacks in this nested stack. |
| `variables` | map | Optional. Key-value pairs of variables accessible in workflows. |
| `rules` | object | Optional. Orchestration rules for this stack. |

### `stacks.names.<name>.rules`

| Key | Type | Description |
| --- | --- | --- |
| `plan_after` | list | Stacks that must be applied before this stack can plan. |
| `apply_after` | list | Stacks that must be applied before this stack can apply. |
| `modified_by` | list | Stacks whose changes also mark this stack as modified. |
| `auto_apply` | boolean | `true` applies this stack automatically after a successful plan. |

## Stack Boundaries

[`depends_on`](/docs/reference/orchestration/configuration/when-modified#depends_on-and-stacks) orders directories inside a stack. The `depends_on` of a directory can only name directories in the same stack, or in a stack that shares a nested stack with it. Naming a directory in an unrelated stack is a configuration error: the run reports it and does not plan.

To order two stacks that share no nested stack, use the `plan_after` and `apply_after` rules. To let directories in two stacks depend on each other, put both stacks in one nested stack.

## Examples

### Basic Environment Stacks

```yaml
stacks:
  names:
    development:
      tag_query: 'development'
      variables:
        environment: dev
        aws_account: "111111111111"
      rules:
        auto_apply: true

    staging:
      tag_query: 'staging'
      variables:
        environment: staging
        aws_account: "222222222222"
      rules:
        apply_after:
          - development

    production:
      tag_query: 'production'
      variables:
        environment: prod
        aws_account: "333333333333"
      rules:
        apply_after:
          - staging
```

### Layered Infrastructure

```yaml
stacks:
  names:
    network:
      tag_query: 'network'

    data:
      tag_query: 'database'
      rules:
        plan_after:
          - network

    compute:
      tag_query: 'compute'
      rules:
        plan_after:
          - network

    application:
      tag_query: 'application'
      rules:
        plan_after:
          - data
          - compute
```

### Nested Stacks

```yaml
stacks:
  names:
    us-east-1:
      tag_query: 'us-east-1'
      variables:
        region: us-east-1

    us-west-2:
      tag_query: 'us-west-2'
      variables:
        region: us-west-2

    all-regions:
      stacks:
        - us-east-1
        - us-west-2
      rules:
        auto_apply: true
```

### Modified By Rules

```yaml
stacks:
  names:
    shared:
      tag_query: 'shared in dir'

    base:
      tag_query: 'base in dir'
      rules:
        modified_by:
          - shared
        # plan_after is implicitly set to [shared]

    services:
      tag_query: 'services in dir'
      rules:
        modified_by:
          - base
        plan_after:
          - shared
        # Explicit plan_after, so no implicit construction
```

### Using Stack Variables

```yaml
stacks:
  names:
    production:
      tag_query: 'production'
      variables:
        tf_version: "1.5.7"
        region: "us-east-1"

workflows:
  - tag_query: ''
    engine:
      name: terraform
      version: '${tf_version}'
    plan:
      - type: init
        extra_args: ['-backend-config=region=${region}']
      - type: plan
```

### Integration with Access Control

```yaml
stacks:
  names:
    production:
      tag_query: 'production'

access_control:
  policies:
    - tag_query: 'stack_name:production'
      plan: ['*']
      apply: ['team:sre']
```

## Related

- [Stacks guide](/docs/orchestration/workflows/advanced/stacks)
- [when_modified](/docs/reference/orchestration/configuration/when-modified)
- [Layered runs](/docs/orchestration/workflows/advanced/layered-runs)
- [Stacks API](/docs/reference/api/stacks)
