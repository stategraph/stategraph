---
title: Import Commands
description: Use stategraph import tf to create a state and import a Terraform state file and its HCL in one step, or to import only the HCL.
order: 8
---


`stategraph import tf` creates a state and imports a Terraform state file and its HCL in one step, or with `--hcl` the HCL alone. It is the recommended onboarding command.

To upload only the state file, use [`stategraph states import`](/docs/cli/states). The deprecated [`stategraph hcl import`](/docs/cli/hcl) imports only the HCL.

## stategraph import tf

Run it from the root of your Terraform module, so that it can find the HCL.

```bash
stategraph import tf --tenant <tenant-id> --name <state-name> [options] [<state-file>]
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<state-file>` | Yes, unless `--hcl` | Path to the Terraform state file |

### Options

| Option | Required | Description |
|--------|----------|-------------|
| `--tenant` | Yes | Tenant ID (UUID), or set `STATEGRAPH_TENANT_ID` |
| `--name` | For a new state | Name of the state to create. With `--overwrite` and no `stategraph.json`, the command creates a new state with this name. |
| `--workspace` | No | Workspace for the state (default: `"default"`) |
| `--group` | No | Group ID for the state |
| `--overwrite` | No | Overwrite an existing state, with the state ID from `stategraph.json`. The import replaces the contents of the state: anything committed to it that this import does not contain is deleted. Transaction history, cost data, and security data stay. |
| `--hcl` | No | Import only the HCL configuration, with no state file. Omit `<state-file>`. The recorded resources and instances of the state do not change. Only its configuration, variable values, attached files, and revision hashes are replaced. |
| `--no-write-config` | No | Do not write a `stategraph.json` file |
| `--var` | No | Set a variable (`key=value`, repeatable) |
| `--var-file` | No | Path to a variable file |
| `--attach-files` | No | Attach files to the resources that match an address glob: `ADDRESS_GLOB=FILE_GLOB`, for example `'module.foo.*=**/*.yml'`. Repeatable. File globs for the same address glob are combined. |
| `--attach-dest` | No | Destination directory for the files attached at an address glob: `ADDRESS_GLOB=DEST`, for example `'module.foo.*=${path.module}/config'`. `DEST` supports `${path.module}` and `${path.root}`, each with an optional relative subdirectory. Without it, the files of an address go to the bundle root. Repeatable. |
| `--diagnostics` | No | Evaluate the HCL with low-cost tracing. Optional mode: `rollup`, `on` (default for a bare `--diagnostics`), `detail`, `verbose`, or `perf`. See [Diagnostics](/docs/cli/diagnostics). |
| `--batch-size` | No | Batch size for transaction log appends (performance tuning) |
| `--parallel-batches` | No | Number of parallel batches for transaction log appends (performance tuning) |
| `-y` | No | Auto-confirm interactive prompts |
| `--silent` | No | Suppress prompt output (only with `-y`) |

Give the same `--var` and `--var-file` flags as to `terraform plan`, so that the HCL evaluates as it does in Terraform.

### Example

Pull your current state, then import it:

```bash
# From the root of your Terraform module
terraform state pull > terraform.tfstate

stategraph import tf \
  --tenant 550e8400-e29b-41d4-a716-446655440000 \
  --name "networking" \
  terraform.tfstate
```

The import writes a `stategraph.json` to the current directory, and binds the directory to the new state. Commit it: later commands, such as `stategraph tf plan`, use it to find the state.

To check the import:

```bash
stategraph states summary --state <state-id>
```

### Replacing an existing state

To replace an imported state with new HCL and state data, add `--overwrite`:

```bash
stategraph import tf --overwrite \
  --tenant 550e8400-e29b-41d4-a716-446655440000 \
  --name "networking" \
  terraform.tfstate
```

### Importing HCL only

Use `--hcl` for a state whose infrastructure does not exist yet, or to record the configuration of a state again with no change to what is deployed:

```bash
# A new state for infrastructure that does not exist yet
stategraph import tf --hcl \
  --tenant 550e8400-e29b-41d4-a716-446655440000 \
  --name "networking"

# Re-record the configuration of the state bound in stategraph.json
stategraph import tf --hcl --overwrite \
  --tenant 550e8400-e29b-41d4-a716-446655440000
```

### Attaching external files

If your HCL reads files with `file()`, `templatefile()`, or similar functions, tell Stategraph which files belong to which resources, so that change detection includes them:

```bash
stategraph import tf \
  --tenant <tenant-id> \
  --name "app" \
  --attach-files 'module.app.*=templates/*.tpl' \
  terraform.tfstate
```

In `--attach-dest`, `${path.module}` is the module directory of the matched block, and `${path.root}` is the bundle root:

```bash
stategraph import tf \
  --tenant <tenant-id> \
  --name "app" \
  --attach-files 'module.app.*=templates/*.tpl' \
  --attach-dest 'module.app.*=${path.module}/templates' \
  terraform.tfstate
```

After the import, manage these mappings with [`stategraph config files`](/docs/cli/config).

## Next Steps

- [Import your Terraform state](/docs/infrastructure-as-a-database/import-state): the guided quickstart.
- [Set up Infrastructure as a Database](/docs/infrastructure-as-a-database/setup): the full onboarding workflow.
- [Terraform Commands](/docs/cli/tf): plan and apply after the import.
- [States Commands](/docs/cli/states): inspect the imported state.
- [Config Commands](/docs/cli/config): manage attached file globs.
