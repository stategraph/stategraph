---
title: storage
description: Reference for the storage key in .stategraph/config.yml. Keep plan files in the server database, an S3 bucket, custom commands, or nowhere.
order: 22
---


`storage` sets where Stategraph Orchestration stores plan files, so that you control their security and access. The default is the Orchestration database. A workflow can also set `storage` to override the top-level value for the dirspaces that it matches.

## Default Configuration

```yaml
storage:
  plans:
    method: terrateam
```

## Storage Methods

The `method` key sets how plans are stored: `terrateam`, `s3`, `cmd`, or `none`.

### Server Storage

`method: terrateam`, the default, stores plan files in the database of the Orchestration server. It accepts no other keys.

### S3-compatible Storage

`method: s3` stores plans in S3-compatible storage. `bucket`, `region`, and the access keys support environment variables.

| Key | Type | Description |
| --- | --- | --- |
| `bucket` | string | Bucket for the plans. Required. |
| `region` | string | Region of the bucket. Required. |
| `path` | string | Path of the plans in the bucket. Default is `terrateam/plans/$dir/$workspace/$date-$time-$token`. See [template variables](#template-variables). |
| `access_key_id` | string | Access key ID for authentication. Optional. |
| `secret_access_key` | string | Secret access key for authentication. Optional. |
| `delete_used_plans` | boolean | Deletes the plan after use. Default is `true`. |
| `store_extra_args` | list | More arguments for `aws s3 cp` when it stores a plan. Optional. |
| `fetch_extra_args` | list | More arguments for `aws s3 cp` when it fetches a plan. Optional. |
| `delete_extra_args` | list | More arguments for `aws s3 rm` when it deletes a plan. Optional. |

### Custom Command Storage

`method: cmd` runs your own commands to store, fetch, and delete plans. The commands support environment and template variables.

| Key | Type | Description |
| --- | --- | --- |
| `delete` | list of strings | Command to delete the plan after use. Optional. |
| `fetch` | list of strings | Command to fetch the plan. Required. |
| `store` | list of strings | Command to store the plan. Required. |

### No Persistent Plan Storage

`method: none` does not store the plan file after the plan workflow completes.

| Key | Type | Description |
| --- | --- | --- |
| `unsafe_apply_without_plan` | boolean | Lets an apply run when no plan file was stored. Default is `false`. |

With `false`, the apply fails, because no saved plan file is available. With `true`, the apply evaluates the configuration again and applies that result.

!!! warning "The reviewed plan is not the applied plan"
    With `method: none`, Orchestration cannot apply the exact binary plan reviewed in the pull request. The apply workflow runs a new non-interactive apply. Use it only where avoiding stored plan files matters more than applying the reviewed plan.

## Template Variables

Variables available during plan and apply operations:

| Variable | Description |
| --- | --- |
| `date` | Date of the plan operation, in `YYYY-MM-DD` format. |
| `dir` | Directory, for example `foo/bar/baz`. |
| `plan_path` | Path on disk of the plan. |
| `plan_dst_path` | Destination path on disk for a fetched plan. |
| `time` | Time of the plan operation, in `HHMMSS` format. |
| `token` | Unique token for the run. |
| `workspace` | Workspace, for example `default`. |

## Examples

### Storing Plans in AWS S3

```yaml
storage:
  plans:
    method: s3
    bucket: my-plan-bucket
    region: us-west-2
    access_key_id: $AWS_ACCESS_KEY_ID
    secret_access_key: $AWS_SECRET_ACCESS_KEY
```

### Custom Commands for Plan Storage

```yaml
storage:
  plans:
    method: cmd
    store: ['gsutil', 'cp', '$plan_path', 'gs://my-plan-bucket/terrateam/plans/$dir/$workspace/$date-$time-$token']
    fetch: ['gsutil', 'cp', 'gs://my-plan-bucket/terrateam/plans/$dir/$workspace/$date-$time-$token', '$plan_dst_path']
    delete: ['gsutil', 'rm', 'gs://my-plan-bucket/terrateam/plans/$dir/$workspace/$date-$time-$token']
```

### Disabling Plan Storage for a Workflow

```yaml
storage:
  plans:
    method: s3
    bucket: my-plan-bucket
    region: us-west-2

workflows:
  - tag_query: "engine:terragrunt"
    engine:
      name: terragrunt
    storage:
      plans:
        method: none
        unsafe_apply_without_plan: true
```

## Related

- [Plan file storage](/docs/orchestration/security/plan-file-storage)
- [workflows](/docs/reference/orchestration/configuration/workflows)
