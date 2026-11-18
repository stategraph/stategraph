---
title: CLI
description: Install and configure the stategraph CLI to manage states, run SQL queries and gap analysis, and automate from the terminal.
order: 1
---


The `stategraph` CLI is the command-line client for Infrastructure as a Database. It works with states, transactions, SQL queries, cost, and security data, from the terminal, in scripts, and in automation. It runs on your machine or CI runner. The server does not run your plans and applies.

Stategraph Orchestration runs start from [pull request commands](/docs/reference/orchestration/commands), not from the CLI.

## Installation

Install the binary with the install script, Homebrew, APT, or a download. The Docker image also works, but a container needs volume mounts and environment variables. The [releases page](https://github.com/stategraph/releases/releases) lists the versions.

### Install Script (macOS & Linux)

Install the latest version:

```bash
curl -sSL https://get.stategraph.com/install.sh | sh
```

### Homebrew (macOS)

```bash
brew tap stategraph/stategraph
brew install stategraph
```

To upgrade:

```bash
brew upgrade stategraph
```

### APT (Debian & Ubuntu)

```bash
# Add the signing key
curl -fsSL https://stategraph.github.io/releases/apt/KEY.gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/stategraph.gpg

# Add the repository
echo "deb [signed-by=/etc/apt/keyrings/stategraph.gpg] https://stategraph.github.io/releases/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/stategraph.list

# Install
sudo apt update
sudo apt install stategraph
```

To upgrade:

```bash
sudo apt update
sudo apt upgrade stategraph
```

The APT packages are for `amd64` and `arm64`. For RPM-based distributions, use the yum repository on [Releases](/docs/reference/releases).

### Binary Installation

Download the file for your platform from the [releases page](https://github.com/stategraph/releases/releases), then install it:

| Platform | File |
|----------|------|
| macOS (Apple Silicon) | `stategraph-macos-arm64.tar.gz` |
| Linux (amd64) | `stategraph-linux-amd64.tar.gz` |
| Linux (arm64) | `stategraph-linux-arm64.tar.gz` |

```bash
tar xzf stategraph-<platform>.tar.gz
sudo mv stategraph /usr/local/bin/
```

Check the installation:

```bash
stategraph --version
stategraph --help
```

With no arguments, `stategraph` shows a getting-started screen. `--help` shows all commands and aliases.

### Docker

```bash
docker pull ghcr.io/stategraph/stategraph:<version>
```

#### Extract the binary from Docker

Without Homebrew or curl, copy the binary out of the image:

```bash
docker create --name sg-tmp ghcr.io/stategraph/stategraph:<version>
docker cp sg-tmp:/usr/local/bin/stategraph ./stategraph
docker rm sg-tmp
sudo mv stategraph /usr/local/bin/
```

#### Running the CLI via Docker

In CI pipelines or containers, mount your working directory and pass the environment variables:

```bash
docker run --rm \
  -e STATEGRAPH_API_BASE \
  -e STATEGRAPH_API_KEY \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/stategraph/stategraph:<version> \
  states import --tenant <tenant-id> --name "networking" terraform.tfstate
```

Or create an alias:

```bash
alias stategraph='docker run --rm -e STATEGRAPH_API_BASE -e STATEGRAPH_API_KEY -v $(pwd):/workspace -w /workspace ghcr.io/stategraph/stategraph:<version>'
```

## Configuration

### API Base URL

Set the Stategraph server URL:

```bash
export STATEGRAPH_API_BASE=https://stategraph.example.com
```

Or give `--api-base` with each command, after the subcommand:

```bash
stategraph user whoami --api-base https://stategraph.example.com
```

### Authentication

The CLI sends an access token as a Bearer token. Create one in the console under **Settings**, or with [`stategraph user access-tokens create`](/docs/cli/user), then export it:

```bash
export STATEGRAPH_API_KEY="<your-access-token>"
stategraph user tenants list
```

For what a token can do, see [Access tokens and capabilities](/docs/admin/access-control/access-tokens).

### Telemetry

After each command, the CLI sends one event to `https://telemetry.terrateam.io/v1/sgc_events`. The event holds:

| Field | Value |
|-------|-------|
| `sgc_version` | The CLI version. |
| `subcommand` | The command names, for example `["tf", "plan"]`. Arguments and flag values are not part of it. |
| `return_code` | The exit code of the command. |
| `error_variant` | `Ok`, or the name of the error. |
| `tenant_id` | The tenant ID from `STATEGRAPH_TENANT_ID` or `--tenant`, when the command takes one. |
| `group_id` | The group ID from `--group` or `stategraph.json`. |
| `user_id`, `user_email` | The user that `/api/v1/whoami` returns for `STATEGRAPH_API_KEY`. |

The send has a limit of 1.5 seconds. A failed send does not change the output or the exit code of the command.

`STATEGRAPH_TELEMETRY_ENDPOINT` controls where the event goes:

| Value | Effect |
|-------|--------|
| `0` or `disabled` | The CLI sends no event. |
| A URL | The CLI sends the event to that URL. |
| A path that starts with `/` | The CLI appends the event to that file, one JSON object per line. |

To turn telemetry off:

```bash
export STATEGRAPH_TELEMETRY_ENDPOINT=0
```

## Command Structure

```text
stategraph <command> <subcommand> [options]
```

### Available Commands

| Command | Description |
|---------|-------------|
| [`stategraph info`](/docs/cli/utilities) | Current user, tenants, and server version, in one call |
| [`stategraph user`](/docs/cli/user) | User identity and tenant membership |
| [`stategraph capabilities`](/docs/cli/capabilities) | Default capabilities and group rules |
| [`stategraph import`](/docs/cli/import) | Import a state file and its HCL in one step |
| [`stategraph states`](/docs/cli/states) | Manage states: create, list, import, export, query, blast radius |
| [`stategraph tf`](/docs/cli/tf) | `plan`, `apply`, `show`, and `mtx`, which plans several directories in one transaction |
| [`stategraph refactor`](/docs/cli/refactor) | Track renames and module moves, and write `moved` blocks |
| [`stategraph tx`](/docs/cli/transactions) | Transactions: create, list, plan-time cost, abort, logs |
| [`stategraph sql`](/docs/cli/sql) | SQL queries and schema discovery |
| [`stategraph tenant`](/docs/cli/tenant) | Gap analysis for unmanaged resources |
| [`stategraph cost`](/docs/cli/cost) | Cost, attribution, history, and FOCUS billing sources |
| [`stategraph security`](/docs/cli/security) | Scan history, findings, severity rollup, transaction impact, and re-scan |
| [`stategraph hcl`](/docs/cli/hcl) | List addresses, evaluate expressions, and convert HCL and JSON |
| [`stategraph diagnostics`](/docs/cli/diagnostics) | Trace HCL evaluation locally, with no API calls, for onboarding |
| [`stategraph config`](/docs/cli/config) | Edit `stategraph.json`: attached files and ephemeral tfvars |
| [`stategraph version`](/docs/cli/utilities) | Client and server versions |
| [`stategraph test`](/docs/cli/hcl) | Debug helpers: `test tf load` prints the parsed HCL of a module |

### Aliases

| Alias | Expands to |
|-------|------------|
| `stategraph plan` | [`stategraph tf plan`](/docs/cli/tf) |
| `stategraph apply` | [`stategraph tf apply`](/docs/cli/tf) |
| `stategraph query` | [`stategraph sql query`](/docs/cli/sql) |
| `stategraph whoami` | [`stategraph user whoami`](/docs/cli/user) |
| `stategraph gaps` | [`stategraph tenant gaps analyze`](/docs/cli/tenant) |
| `stategraph blast-radius` | [`stategraph states instances blast-radius`](/docs/cli/states) |
| `stategraph caps` | [`stategraph capabilities`](/docs/cli/capabilities) |

In a pull request comment, `stategraph plan` and `stategraph apply` are [Orchestration commands](/docs/reference/orchestration/commands).

## Quick Examples

### Orient yourself

```bash
stategraph info
```

In `table` or `simple` format, `info` also prints suggested next steps. Run it first, as a new user or as an AI agent.

### Check current user

```bash
stategraph user whoami
```

### List your tenants

```bash
stategraph user tenants list
```

### List states in a tenant

```bash
stategraph states list --tenant <tenant-id>
```

### Import a Terraform state file

Run it from the root of your Terraform module, with the `--var-file` and `--var` flags that you give to `terraform plan`:

```bash
stategraph import tf \
  --tenant <tenant-id> \
  --name "networking" \
  terraform.tfstate
```

To replace an existing state with new HCL and state data, add `--overwrite`:

```bash
stategraph import tf --overwrite \
  --tenant <tenant-id> \
  --name "networking" \
  terraform.tfstate
```

For a guided import, see [Import your Terraform state](/docs/infrastructure-as-a-database/import-state). For the full workflow, with plan and apply, see [Set up Infrastructure as a Database](/docs/infrastructure-as-a-database/setup).

### Run an SQL query

```bash
stategraph sql query "SELECT type, count(*) FROM resources GROUP BY type"
```

### Get blast radius for a resource

```bash
stategraph states instances blast-radius --state <state-id> "aws_vpc.main"
```

### Run gap analysis

```bash
stategraph tenant gaps analyze --tenant <tenant-id> --provider aws
```

### Attach data files

When your HCL reads files with `file()`, `templatefile()`, or similar functions, `stategraph config files` records which files a change includes:

```bash
# Attach file globs to an address (takes the union with any existing globs)
stategraph config files attach --workspace default --address 'module.app.*' './templates/*.tpl'

# Remove specific globs (omit the globs to remove the whole address entry)
stategraph config files remove --workspace default --address 'module.app.*' './templates/*.tpl'
```

For the glob grammar, `--dest`, `--expr`, `--recursive`, and ephemeral tfvars, see [Config Commands](/docs/cli/config).

## Common Options

Most subcommands accept these options, after the subcommand:

| Option | Environment Variable | Description |
|--------|---------------------|-------------|
| `--api-base` | `STATEGRAPH_API_BASE` | Base URL for API calls |
| - | `STATEGRAPH_API_KEY` | Access token |
| `--tenant` | `STATEGRAPH_TENANT_ID` | Tenant ID. Most commands require it. |
| `--workspace` | `STATEGRAPH_WORKSPACE` | Workspace name (default: `default`) |
| `-y` | `STATEGRAPH_NON_INTERACTIVE` | Answer yes to interactive prompts |
| `--silent` | `STATEGRAPH_SILENT` | Suppress prompt output. Use it with `-y`. |
| `--loggers` | `STATEGRAPH_LOGGERS` | Logging configuration |
| `-v`, `--verbose` | - | Increase verbosity. A third `-v` adds nothing. |
| `--verbosity` | `STATEGRAPH_LOG_LEVEL` | Log level: `quiet`, `error`, `warning` (default), `info`, or `debug`. Overrides `-v`. |
| `-q`, `--quiet` | - | Be quiet. Overrides `-v` and `--verbosity`. |
| `--format` | - | Output format: `json`, `table`, or `simple` |
| `--version` | - | Print the CLI version and exit |

## Output Format

Query and listing commands accept `--format`:

| Format | Use case |
|--------|----------|
| `json` | Scripts and `jq` |
| `table` | Human-readable aligned columns |
| `simple` | One row per line, tab-separated, no headers |

```bash
# JSON for scripting
stategraph states list --tenant <tenant-id> --format json | jq '.results[].name'

# Table for humans
stategraph states list --tenant <tenant-id> --format table

# Simple tab-separated for shell pipelines
stategraph user tenants list --format simple | awk '{print $1}'
```

`tx` subcommands always print JSON. They reject `--format` with `unknown option --format`.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Runtime error: authentication, connection, or a failed command |
| 2 | `tf plan` or `tf mtx` with `--detailed-exitcode`: the plan succeeded and has changes |
| 123 | Other errors, reported on standard error |
| 124 | Command-line parsing error (missing or invalid options) |
| 125 | Unexpected internal error |

## Next Steps

- [User Commands](/docs/cli/user): identity and tenant membership.
- [States Commands](/docs/cli/states): manage Terraform states.
- [Terraform Commands](/docs/cli/tf): plan and apply through Stategraph.
- [SQL Commands](/docs/cli/sql): query your infrastructure.
- [Terraform CLI compatibility](/docs/reference/terraform-compatibility): how Terraform commands map to the CLI.
- [API Reference](/docs/reference/api): REST API documentation.
