---
title: Refactor into modules
description: "Use an AI agent with Stategraph refactor sessions to move resources into modules, prove the plan is moves only, and apply without manual state moves."
order: 6
---


Restructure a root module, such as repeated resources carved into one reusable module, and keep every state address. The agent writes the module and records each move. Stategraph proves the plan contains moves and nothing else before anything is applied. Nobody runs `terraform state mv`.

## How Stategraph does it

- `stategraph refactor start` opens a session for the root module. `stategraph refactor step` records each address move on the server: `OLD=NEW`.
- While the session is open, `stategraph tf plan` carries the moves. Each moved resource shows its previous address and a `no-op` action.
- `stategraph tf apply plan.json` rewrites the state addresses, writes `moved_stategraph.tf`, and closes the session. No resource is created or destroyed.
- Until the apply, `stategraph refactor abort` discards the session and leaves state as it was.

## Before you begin

- [Set up your agent](/docs/ai/quickstart), and allow it to edit and create files, so it can change HCL.
- A token that can plan and apply the state. The apply only rewrites addresses.
- A root module that plans clean. Run `stategraph tf plan` first: drift in the resources that the refactor touches shows up as changes in the refactor plan.

## Steps

### 1. Ask for the refactor

```text
In this root module (acme-compute), the four ECR repositories each repeat the same pair of
resources: a repository and its lifecycle policy. Refactor them into one reusable module at
modules/ecr_repository, called once per service, without destroying or recreating anything.
You have my authorization to finalize the refactor with apply once the plan shows moves only.
```

The agent writes `modules/ecr_repository`, replaces each pair of resources with a module call, and records the moves:

```bash
stategraph refactor start
stategraph refactor step aws_ecr_repository.api_server=module.ecr_api_server.aws_ecr_repository.this aws_ecr_lifecycle_policy.api_server=module.ecr_api_server.aws_ecr_lifecycle_policy.this
stategraph tf plan --detailed-exitcode --skip-costs --skip-security --out plan.json
```

The new module call in `ecr.tf`:

```hcl
module "ecr_api_server" {
  source = "./modules/ecr_repository"

  name             = "${local.project}/api-server"
  keep_image_count = 20
  tags = merge(local.common_tags, {
    Name    = "${local.project}-api-server"
    Service = "api"
  })
}
```

### 2. Check that the plan is moves only

This is the gate. The agent applies only when the count of changes other than moves is `0`:

```bash
stategraph tf show --json plan.json | jq -r '.resource_changes[] | select(.previous_address != null) | "\(.previous_address) -> \(.address) \(.change.actions)"'
stategraph tf show --json plan.json | jq '[.resource_changes[] | select(.change.actions != ["no-op"])] | length'
```

Output:

```text
aws_ecr_repository.admin_panel -> module.ecr_admin_panel.aws_ecr_repository.this ["no-op"]
aws_ecr_lifecycle_policy.admin_panel -> module.ecr_admin_panel.aws_ecr_lifecycle_policy.this ["no-op"]
aws_ecr_repository.api_server -> module.ecr_api_server.aws_ecr_repository.this ["no-op"]
aws_ecr_lifecycle_policy.api_server -> module.ecr_api_server.aws_ecr_lifecycle_policy.this ["no-op"]
...
0
```

### 3. Apply and confirm

```bash
stategraph tf apply plan.json
stategraph tf plan --detailed-exitcode --skip-costs --skip-security
```

Output:

```text
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

No changes detected.
```

Commit the module, the edited files, and `moved_stategraph.tf`. Leave out `.stategraph/` and `plan.json`.

## When the plan is not moves only

The same request on another root module found drift that was there before: alarms whose tags in state did not match the HCL. The agent recorded every move and stopped before the apply:

```text
I did not apply. The refactor is written and all nine queue moves are recorded, but the plan
isn't moves-only, so your authorization doesn't cover applying it.

The plan also shows 4 in-place updates: aws_cloudwatch_metric_alarm.jobs_dlq, jobs_age,
email_dlq and webhooks_dlq each add the tags Environment, ManagedBy, Project, Severity and Team.

Pick one:
1. Apply as is. It's a real change to those alarms, so I need your explicit OK.
2. Fix the tag difference separately first, then redo the refactor.
3. Leave it open and decide later.
```

Fix the drift with a normal change first, then run the refactor again.

## Next steps

- [Refactoring](/docs/infrastructure-as-a-database/refactoring): how refactor sessions work
- [Refactor commands](/docs/cli/refactor): the CLI reference
- [Guardrails](/docs/ai/guardrails): reversible and irreversible actions
