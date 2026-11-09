---
title: Refactoring
description: Rename and move Terraform resources without state loss: a refactor session finds the moves and writes the moved blocks for you.
order: 6
---


A refactor session follows your HCL changes across plans, and writes Terraform `moved` blocks to `moved_stategraph.tf` in your module when you finish. Use it to rename a resource or a module, move a resource into or out of a module, or restructure files without an infrastructure change.

## Why

Terraform identifies a resource by its address. If you rename `aws_instance.web` to `aws_instance.frontend`, a plain plan proposes to destroy one instance and create another. A `moved` block tells Terraform that both addresses are the same object, so the plan becomes a no-op move. Hand-written `moved` blocks and `terraform state mv` are slow and easy to get wrong in a large restructure.

A session detects the moves for you. Terraform and OpenTofu read the `moved` blocks on the next plan, so the state follows the refactor.

- A session handles moves that are visible in HCL.
- A change only in provider behavior, such as a provider that renames an attribute, is out of scope.

## Workflow

Run all commands from the root module directory, where you run `stategraph tf plan`. The session applies to that module only, and keeps its state in a `.stategraph` directory next to it. Do not commit that directory while a session is open.

### 1. Start the session

```bash
stategraph refactor start
```

This takes a snapshot of the current HCL and state for later plans to compare with.

### 2. Plan the refactor

Edit your HCL, then plan as usual:

```bash
stategraph tf plan --tenant <tenant-id> --out plan.json
```

While a session is open, `stategraph tf plan` runs a detection step. It prints `WARNING: Running in refactor mode.`, maps each removed address to its new address, and adds the detected `moved` blocks to the plan.

If detection cannot tell where a resource moved, for example after a rename and an attribute change in one edit, the plan stops. It lists the unmatched added and removed addresses, and tells you to run `stategraph refactor step`. Give the mapping, then plan again:

```bash
stategraph refactor step aws_instance.web=aws_instance.frontend
stategraph tf plan --tenant <tenant-id> --out plan.json
```

`step` accepts several `OLD=NEW` mappings, one per argument. Run it as often as necessary.

### 3. Review the moves

A correct refactor shows moves, not destroy-and-create pairs. Show a saved plan again at any time:

```bash
stategraph tf show plan.json
```

Edit and plan again until the plan matches your intent. Each plan runs another detection step, so mappings accumulate across the session.

### 4. Apply

```bash
stategraph tf apply plan.json
```

`stategraph tf apply` also runs a detection step. After the commit succeeds, it prints `WARNING: Running in refactor mode. Finalizing refactor session.`, completes the session, and writes `moved_stategraph.tf`. Commit that file with the refactored HCL.

`stategraph tf mtx` does not drive a session. Refactor with `tf plan` and `tf apply`.

## Driving the session by hand

`step` detects the changes since the last `start` or `step`, and prints each mapping as `OLD -> NEW`. If it cannot match an address, it exits non-zero and lists the unmatched addresses:

```bash
stategraph refactor step
stategraph refactor step aws_instance.web=aws_instance.frontend
```

Finalize the session and write the accumulated mappings to `moved_stategraph.tf`:

```bash
stategraph refactor complete
```

Discard the session and its state, to back out of a refactor or to start over from a bad state:

```bash
stategraph refactor abort
```

## Next steps

- [Refactor commands](/docs/cli/refactor): the command reference.
- [Setup](/docs/infrastructure-as-a-database/setup): the `stategraph tf` workflow.
- [Refactor into modules](/docs/ai/guides/refactor): an agent drives the `stategraph-refactor` skill
