---
title: engine
description: Reference for the engine key in .stategraph/config.yml. Choose Terraform, OpenTofu, Terragrunt, CDKTF, Pulumi, Stategraph, or a custom engine.
order: 13
---


`engine` sets the tool that Stategraph Orchestration runs for plan and apply. Set it for the whole repository, or per workflow under the `workflows` key.

| `name` | Runs |
| --- | --- |
| `terraform` | The Terraform CLI. This is the default. |
| `tofu` | OpenTofu. |
| `stategraph` | The `stategraph` CLI, with your state in Infrastructure as a Database. |
| `terragrunt` | Terragrunt, on Terraform or OpenTofu. |
| `cdktf` | CDKTF, for infrastructure in TypeScript, Python, Go, or Java, on Terraform or OpenTofu. |
| `pulumi` | Pulumi. |
| `custom` | Your own command for each step. |

## Default Configuration

```yaml
engine:
  name: terraform
```

## Keys

`name` is required when `engine` is set. The other keys depend on the engine.

`default_tf_version` is an older, top-level form of `engine`. Without `engine`, `default_tf_version: "1.5.0"` is the same as `engine: { name: terraform, version: "1.5.0" }`. With `engine`, it sets the Terraform version of the `terragrunt`, `cdktf`, and `stategraph` engines that do not set `tf_version`. Use `engine`.

### terraform and tofu

| Key | Type | Description |
| --- | --- | --- |
| `name` | string | `terraform` or `tofu` |
| `override_tf_cmd` | string | The program to call in place of `terraform` or `tofu` |
| `version` | string | The version of `terraform` or `tofu` |
| `outputs` | object | See [outputs](#outputs) |

### terragrunt

| Key | Type | Description |
| --- | --- | --- |
| `name` | string | `terragrunt` |
| `override_tf_cmd` | string | The program to call in place of Terragrunt |
| `tf_cmd` | string | The Terraform-compatible program under Terragrunt. Default is `terraform`. |
| `tf_version` | string | The version of that program (Terraform or OpenTofu) |
| `version` | string | The version of Terragrunt |
| `outputs` | object | See [outputs](#outputs) |

### cdktf

| Key | Type | Description |
| --- | --- | --- |
| `name` | string | `cdktf` |
| `override_tf_cmd` | string | The Terraform or OpenTofu program that plans and applies the synthesized code, in place of `terraform` or `tofu` |
| `tf_cmd` | string | The Terraform-compatible program under CDKTF. Default is `terraform`. |
| `tf_version` | string | The version of that program (Terraform or OpenTofu) |
| `outputs` | object | See [outputs](#outputs) |

### stategraph

Runs the `stategraph` CLI, with your state in Infrastructure as a Database. It needs a Stategraph server, and a `stategraph.json` in each directory, committed to the repository. For setup, secrets, and limits, see [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration).

| Key | Type | Description |
| --- | --- | --- |
| `name` | string | `stategraph` |
| `version` | string | Optional. The version of the `stategraph` CLI to install. |
| `override_tf_cmd` | string | The Terraform or OpenTofu program that the CLI calls, in place of `terraform` or `tofu` |
| `tf_cmd` | string | The Terraform-compatible program that the CLI runs. Default is `terraform`. |
| `tf_version` | string | The version of that program (Terraform or OpenTofu) |

The runner reads `STATEGRAPH_API_BASE`, `STATEGRAPH_API_KEY`, and `STATEGRAPH_TENANT_ID` from the environment. All three are required. The `stategraph` engine does not collect outputs. It reports the Stategraph transaction of each plan and apply to Orchestration, which uses it to let pull requests apply the same directory in parallel, and to refuse an apply that overlaps another pull request's before it starts. See [Locks in Infrastructure as a Database](/docs/orchestration/workflows/advanced/lock-management#locks-in-infrastructure-as-a-database).

### pulumi

| Key | Type | Description |
| --- | --- | --- |
| `name` | string | `pulumi` |

The `pulumi` engine takes no other keys.

### custom

Each step is optional. Orchestration skips a step that you do not set.

| Key | Type | Description |
| --- | --- | --- |
| `init` | array | The command for the init step |
| `plan` | array | The command for the plan step. To pass a plan file to the apply step, write it to the path in `TERRATEAM_PLAN_FILE`. The file format is up to your engine. |
| `diff` | array | The command that prints a readable diff of the plan |
| `resource_summary` | array | The command that prints the resource counts of the plan as a JSON object with the integer keys `created`, `updated`, `replaced`, `deleted`, and `imported`. It runs after a plan with changes, and the counts show in the status check description and the summary comment. The status check description shows `imported` only when it is above zero. Orchestration skips the counts when the command fails or prints no JSON object. |
| `apply` | array | The command for the apply step |
| `unsafe_apply` | array | The command for [`stategraph apply-autoapprove`](/docs/reference/orchestration/commands/apply-autoapprove), which applies with no stored plan file |
| `outputs` | array | The command that returns the output values as a JSON string |

## outputs

By default, Orchestration collects and stores the outputs of each apply. `outputs` controls this. A [`depends_on` that names an output](/docs/reference/orchestration/configuration/when-modified#depending-on-outputs) compares the stored outputs, so a directory with `collect: false` reports no change and its dependents are pruned.

| Key | Type | Description |
| --- | --- | --- |
| `collect` | boolean | `true` collects the outputs, `false` turns it off. Default is `true`. |

## Examples

### Using Terraform

```yaml
engine:
  name: terraform
  version: '1.0.0'
```

### Using OpenTofu

```yaml
engine:
  name: tofu
  version: '1.9.0'
```

### Using Terragrunt with a Specific Terraform Version

```yaml
engine:
  name: terragrunt
  tf_version: '1.5.7'
```

### Using Terragrunt with OpenTofu

```yaml
engine:
  name: terragrunt
  tf_cmd: tofu
```

### Using CDKTF with the Latest Terraform Version

```yaml
engine:
  name: cdktf
```

### Using Pulumi

```yaml
engine:
  name: pulumi
```

### Using Stategraph

```yaml
engine:
  name: stategraph
```

### Using Stategraph with OpenTofu

```yaml
engine:
  name: stategraph
  tf_cmd: tofu
  tf_version: '1.7.0'
```

The runner needs the secrets and the `stategraph.json` files in [stategraph](#stategraph).

### Using a Custom Engine

```yaml
engine:
  name: custom
  init: ['echo', 'init']
  plan: ['my-custom-plan']
  diff: ['printf', '+ added foo\n- removed bar\n~ updated baz\n']
  apply: ['my-custom-apply']
  outputs: ['echo', '{"foo": "bar"}']
```

Each step runs a command. Set only the steps that you need.

## Related

- [Engine setup](/docs/orchestration/workflows/advanced/engine-setup)
- [workflows](/docs/reference/orchestration/configuration/workflows)
- [OpenTofu](/docs/orchestration/iac-tools/opentofu)
- [Terragrunt](/docs/orchestration/iac-tools/terragrunt)
- [CDKTF](/docs/orchestration/iac-tools/cdktf)
- [Pulumi](/docs/orchestration/iac-tools/pulumi)
