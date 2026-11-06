---
title: Troubleshooting
description: Fix common Stategraph errors with sign-in, the stategraph CLI, the console, gap analysis, cost, and Orchestration on GitHub and GitLab.
order: 4
---


This page lists common Stategraph errors and their solutions: sign-in, the `stategraph` CLI, the console, gap analysis, cost, and Orchestration. For a server that does not start, see [Docker Compose troubleshooting](/docs/admin/self-hosting/docker-compose#troubleshooting) and [Health checks](/docs/admin/operations/health-checks). To report a bug, open an [issue](https://github.com/stategraph/stategraph/issues), or see [Support](/docs/support).

## Common Error Messages

| Error | Solution |
|-------|----------|
| `Key_error "..."` | Set the missing environment variable. See [Environment variables](/docs/admin/operations/environment-variables) |
| `Connection refused` | Start the service |
| `Could not connect to Stategraph API` | See [Could not connect](#could-not-connect-to-stategraph-api) |
| `401 Unauthorized` | Check the session, or see [401 Unauthorized](#http-error-401-unauthorized) |
| `redirect_uri_mismatch` | See [OAuth redirect errors](#redirect_uri_mismatch) |
| `command not found` (tf plan/apply) | See [command not found](#command-not-found-running-plan-or-apply) |
| `remote_state_address_unresolved` | See [Remote state address does not resolve](#remote-state-address-does-not-resolve) |
| `TX_CONFLICT` (409) | See [Transaction conflict](#transaction-conflict-tx_conflict-http-409) |
| `503` on `/costs/calculate` | See [Cost analysis disabled](#cost-analysis-disabled-or-returns-503) |
| Unknown-command reply on a pull request | See [Unknown-command reply](#pull-request-comment-gets-an-unknown-command-reply) |
| No reply to a comment command | See [Comment command does nothing](#comment-command-does-nothing) |
| `503` `Orchestration is not enabled on this server.` or `Provisioning is not enabled on this server.` when connecting a GitLab group | See [Cannot connect a GitLab group](#cannot-connect-a-gitlab-group-from-the-console) |
| `Its identity must be verified` on a merge request | See [GitLab pipeline does not start](#gitlab-pipeline-does-not-start) |
| `Unable to start workflow due to missing inputs` (`GITLAB_INPUTS_MISSING_DEFAULTS`) | See [GitLab pipeline does not start](#gitlab-pipeline-does-not-start) |
| GitLab job fails calling back on self-managed GitLab | See [Job fails calling back](#gitlab-job-fails-when-it-calls-back-on-self-managed-gitlab) |

## Authentication Issues

### OAuth redirect errors

#### "redirect_uri_mismatch"

The callback URL does not match the configuration of your OAuth provider.

**Solution**:

1. Set `STATEGRAPH_OAUTH_REDIRECT_BASE` to your exact access URL. The default is `http://localhost:<port>`.
2. Add the exact callback URL to the OAuth provider. The server logs it at startup as `OAUTH2_CALLBACK_URL`: `{STATEGRAPH_OAUTH_REDIRECT_BASE}/oauth2/google/callback` for Google, `{STATEGRAPH_OAUTH_REDIRECT_BASE}/oauth2/oidc/callback` for OIDC.
3. Use the same protocol (http or https) in both.

#### "invalid_client"

The client ID or secret is wrong.

**Solution**:

- Check the credentials in your OAuth provider, and look for extra whitespace or newlines.
- If necessary, make a new secret.

### Session not persisting

**Symptoms**: The login succeeds, then returns to the login page at once.

**Solutions**:

- Make `STATEGRAPH_UI_BASE` exactly match the URL in your browser.
- The cookie is not set, because a proxy strips cookies or because of a SameSite problem: check the cookie handling of your reverse proxy.
- Access uses http, but the configuration uses https: use one protocol.

### Login fails with "invalid CSRF token" (multi-replica)

**Symptoms**: Some logins fail at the OAuth callback with `403 Forbidden: Unable to find a valid CSRF token`, often after a restart or a scale-up.

**Cause**: Without a shared secret, each replica signs the OAuth session and CSRF cookies with its own secret. When the login starts on one replica and the callback goes to another, that replica cannot validate the cookie.

**Solutions**:

- Set `STATEGRAPH_OAUTH_COOKIE_SECRET` to the same value, of 16, 24, or 32 characters, on each replica. Users then also stay logged in across restarts. The Helm chart and the ECS Terraform module create and share a stable value automatically.
- As a stopgap, turn on sticky sessions on the load balancer, so that one replica serves each login.

### "Access denied" after authentication

**Solutions**:

- The email is not in the allowed domain: check `STATEGRAPH_OAUTH_EMAIL_DOMAIN`.
- The user is not in the required Google Group: check the group membership.
- The organization has not approved the OAuth app: ask its admin to approve it.

## Infrastructure as a Database Issues {#state-engine-issues}

### "Could not connect to Stategraph API"

**Symptoms**: A `stategraph` command fails with `Error: Could not connect to Stategraph API.`

**Causes**:

1. The Stategraph server is not running.
2. `STATEGRAPH_API_BASE` has the wrong URL.
3. The network blocks the connection.

**Solution**:

- Test the server, then your access token, at your `STATEGRAPH_API_BASE`:

```bash
# Test connectivity
curl http://localhost:8080/health/ready

# Test with credentials
curl -H "Authorization: Bearer $STATEGRAPH_API_KEY" http://localhost:8080/api/v1/whoami
```

### Transaction conflict (`TX_CONFLICT`, HTTP 409)

**Symptoms**: A commit fails because another transaction changed some of the same resources. The error lists that transaction. Transactions, not state file locks, manage concurrency, so `terraform force-unlock` does not apply.

**Solutions**:

1. Wait for the other transaction to complete. Find its ID among the open transactions of `stategraph tx list --tenant <tenant-id>`.
2. Plan again, then apply the new plan.
3. If a transaction is stuck, abort it:

```bash
stategraph tx abort --tx <tx-id>
```

For how Stategraph detects conflicts, see [Resource locking](/docs/infrastructure-as-a-database/resource-locking).

### "Error: Unauthorized" (HTTP 401) {#http-error-401-unauthorized}

**Solutions**:

- The access token is not valid, or it expired: create a new one. See [Access tokens](/docs/admin/access-control/access-tokens).
- The token has leading or trailing whitespace: remove it.

### Large state timeout

**Symptoms**: Operations on a large state fail.

**Solutions**:

1. Increase `STATEGRAPH_CLIENT_MAX_BODY_SIZE` (default: `512m`).
2. Check the timeouts of your reverse proxy.
3. If possible, split the state.

### "command not found" running plan or apply

**Symptoms**: `stategraph tf plan` or `stategraph tf apply` exits at once and does not run Terraform or OpenTofu.

**Error message**

```text
Error: tofu: command not found. Install OpenTofu or Terraform, or set the TF_CMD environment variable to your binary.
```

**Solution**:

- Install OpenTofu or Terraform on your `PATH`, or set `TF_CMD` to the full path of the binary.

### Plan appears to hang

**Symptoms**: `stategraph tf plan` stops, shows no more output, and does not finish.

**Cause**: Terraform or OpenTofu waits at a prompt, for example for an input variable.

**Solution**:

- Give each required variable with `--var`, a `*.tfvars` file, or a `TF_VAR_*` environment variable.
- Upgrade to the latest CLI. It turns off input prompts, so a missing value gives an error.

### "has not been declared" during plan

**Symptoms**: `stategraph tf plan` fails when it evaluates your configuration.

**Error message**

```text
An input variable with the name "..." has not been declared.
```

`Local value with the name "..." has not been declared.` can also appear.

**Solution**:

- Run `stategraph diagnostics run <dir>` with the `--var`, `--var-file`, and `--workspace` of your plan, to trace how Stategraph evaluates the module. See [Diagnostics](/docs/cli/diagnostics).
- Make sure that the evaluated module declares the variable or `local`, and that its source module resolves as expected.
- Upgrade to the latest CLI, which has several evaluation fixes for this error.

### Remote state address does not resolve {#remote-state-address-does-not-resolve}

**Symptoms**: `stategraph tf plan` fails and does not run Terraform or OpenTofu. The address of a `terraform_remote_state` data source reads a value that Stategraph cannot know at plan time. No plan is produced.

**Error message**

```text
Error: the remote state address of data source data.terraform_remote_state.network names var.network_state_id, and it does not resolve at plan time:
	variable does not resolve at plan time
```

**Solution**:

- Give the address a value that is known at plan time: a tfvar, the `default` of the variable, or the argument of the module call. See [Variables in the address](/docs/infrastructure-as-a-database/multi-state#variables-in-the-address).
- Do not read a resource, a data source, or an output in the address. Stategraph evaluates the address from configuration values only.
- Do not use `count.index`, `each.key`, or `path.*` in the address. Use a tfvar instead.
- Run `stategraph diagnostics run <dir>` with the same `--var` and `--var-file` values to trace the evaluation. See [Diagnostics](/docs/cli/diagnostics).

## Console Issues

### Graph won't render

**Symptoms**: The **Graph Explorer** shows no graph, or reports that the graph exceeds the display limit.

**Causes**:

1. No resource is selected, or the state has no resources.
2. The selected resource has more direct relationships, or a larger graph, than the Graph Explorer draws.

**Solutions**:

- Check the resource count of the state on the **States** screen.
- Select a resource. The Graph Explorer draws its dependencies up to three levels deep.
- For a resource past the limit, use the **Blast Radius** screen, which lists each dependency, or select a resource with fewer direct relationships.

## Gap Analysis Issues

### "Not ready for gap analysis"

**Solutions**:

- Turn on AWS Config in your account.
- Create a configuration aggregator.
- Give Stategraph the required IAM permissions. See [Gap analysis](/docs/infrastructure-as-a-database/query/gap-analysis).

### AWS resources not appearing

**Solutions**:

- Make sure that AWS Config records the resource types.
- Check the aggregator configuration for missing regions.
- Refresh a stale cache with `stategraph tenant gaps analyze --source no-cache` (`source=no-cache` on the API).

## Cost Analysis Issues

### Cost analysis disabled or returns 503

**Symptoms**: `capabilities.costs.enabled` is `false`, `POST .../costs/calculate` returns `503`, or cost analysis stopped after a redeploy, a restart, or a reschedule.

**Cause**: The server started without `STATEGRAPH_COST_ENABLED=true`. For example, the variable was set on a running container, not in the deployment configuration.

**Solution**:

- Set `STATEGRAPH_COST_ENABLED=true` in the deployment configuration (Compose `.env` or `environment:`, the Kubernetes Deployment, or the ECS task definition), then redeploy. See [Enable cost estimation](/docs/admin/self-hosting/cost).

## Orchestration Issues

For the flow of a run, see [Workflows](/docs/orchestration/workflows). For the self-hosted setup, see [Enable orchestration](/docs/admin/self-hosting/orchestration).

### Orchestration does not start {#orchestration-engine-does-not-start}

**Symptoms**: `STATEGRAPH_ORCHESTRATION_ENABLED=true` is set, but pull requests get no plan comment, and the log shows that Orchestration refuses to start.

**Causes**:

1. GitHub: `GITHUB_APP_ID` is set without `GITHUB_WEBHOOK_SECRET`. Orchestration accepts only signed webhook events.
2. GitLab: `GITLAB_APP_ID` is set without `GITLAB_APP_SECRET` or `GITLAB_ACCESS_TOKEN`. The log shows `CONFIG : ERROR` with a `Key_error` that names the variable.

**Solution**:

- Set the missing variable. `GITHUB_WEBHOOK_SECRET` is the webhook secret of your GitHub App. See [Enable orchestration](/docs/admin/self-hosting/orchestration) and [Connect GitLab](/docs/admin/self-hosting/orchestration#connect-gitlab).

### Pull request comment gets an unknown-command reply

**Symptoms**: The bot replies that it does not recognize the command.

**Cause**: The trigger word is `stategraph`. The reply names it.

**Solution**:

- Comment `stategraph plan` or `stategraph apply`. See [Pull request commands](/docs/reference/orchestration/commands).

### Comment command does nothing

**Symptoms**: You comment on a pull request, and nothing happens: no reply and no run.

**Causes**:

1. The comment does not start with a trigger word such as `stategraph`.
2. The comment was edited. Only new comments run commands.
3. On GitLab, the project webhook does not send **Comments** events.

**Solutions**:

- Post a new comment that starts with `stategraph`, for example `stategraph plan`. See [Pull request commands](/docs/reference/orchestration/commands/help).
- On GitLab, turn on **Push events**, **Comments**, **Merge request events**, and **Job events** in the project webhook.

### Plan or apply reports nothing to do

**Symptoms**: The run finishes without a plan or an apply.

**Cause**: The comment gives the reason: nothing matched, everything that matched is already applied, or the run waits for an earlier layer. When a tag query drops directories, the run still occurs, and the comment lists them.

**Solution**:

- Change the tag query, or wait for the earlier layer.
- To plan again the directories whose last plan found no changes, name them: `stategraph plan dir:<path>`. See [plan](/docs/reference/orchestration/commands/plan).

### Per-dirspace status checks are missing {#per-dirspace-status-checks-are-missing}

**Symptoms**: A plan or apply run creates no `stategraph plan: <directory> <workspace>` or `stategraph apply: <directory> <workspace>` check, and a branch protection rule that requires one blocks the pull request.

**Cause**: The pull request impacts more than 50 dirspaces. Above that limit Orchestration creates no per-dirspace checks, whatever [`notifications.plan.status_checks.enabled`](/docs/reference/orchestration/configuration/notifications) and `notifications.apply.status_checks.enabled` say, because one large pull request would otherwise fill the check list of the forge.

**Solution**:

- Do not require a per-dirspace check in branch protection. Require `stategraph apply` instead: Orchestration always creates it, and it holds the pull request until every changed dirspace is applied.
- Split the change into several pull requests, each of which changes 50 dirspaces or fewer, when you need the per-dirspace checks.

### Apply is waiting on work already running

**Symptoms**: An apply posts a comment that names other work that it waits for.

**Cause**: Another run still works on directories and workspaces of the apply.

**Solution**:

- Wait for the named run to finish. If it is stuck, run the command that the comment gives to clear it. See [unlock](/docs/reference/orchestration/commands/unlock).
- A run that never started does not need an unlock. When you request the operation, Orchestration aborts a run whose runner never polled and that is older than [`work_manifests.start_timeout_sec`](/docs/reference/orchestration/configuration/work-manifests), and the work behind it starts. No comment announces this abort.

### Missing plans, or the apply aborts because the plan was superseded

**Symptoms**: The apply comment lists missing plans, or the apply aborts.

**Cause**: Plan and apply run against your branch merged with the current tip of the destination branch. An apply replays the plan that you reviewed, or aborts when another pull request superseded it. The Missing Plans comment gives the reason for each plan, and links the pull request that applied or merged an overlapping directory.

**Solution**:

- Comment `stategraph plan`, review the new plan, then comment `stategraph apply`.

### Automerge did not merge the pull request

**Symptoms**: The apply succeeded and automerge is configured, but the pull request stayed open. For example, the base branch requires a review.

**Solution**:

- Meet the branch requirement, then comment `stategraph plan` or `stategraph apply` to start automerge again. See [automerge](/docs/reference/orchestration/configuration/automerge).

### Plan output in the pull request comment is trimmed

**Symptoms**: The comment of a large run shows only part of the output.

**Cause**: When a comment is too large, Orchestration trims the output of successful steps, and keeps the end of the failed step's output, where the error is.

**Solution**:

- Open the run in the console for the full output. **Steps** shows each step's output as `visible_on` allows, and **Raw** shows every step.

### Cannot claim a GitHub installation from the console

**Symptoms**: On a self-hosted deployment, a tenant admin cannot link their GitHub installation from the console.

**Cause**: The self-serve claim needs the OAuth client of the GitHub App.

**Solution**:

- Set `GITHUB_APP_CLIENT_ID` and `GITHUB_APP_CLIENT_SECRET`.
- Register `{STATEGRAPH_OAUTH_REDIRECT_BASE}/api/v1/vcs-installations/github/claim/callback` as a callback URL on the App.
- Give the App the organization permission Members: read. See [Enable orchestration](/docs/admin/self-hosting/orchestration).

### Cannot connect a GitLab group from the console

**Symptoms**: The GitLab connect wizard stops with an error.

**Error message**

```text
Orchestration is not enabled on this server, so GitLab groups cannot be connected yet.
```

**Causes**:

1. The error above (HTTP `503`): on a self-hosted deployment, Orchestration is off (the server answers `Orchestration is not enabled on this server.`), or `STATEGRAPH_FDW_PROVISIONER_PASSWORD` is not set (`Provisioning is not enabled on this server.`).
2. `This GitLab group already has an installation.` (HTTP `409`): the group is already connected.
3. The wizard shows **Tenant admin required**: only a tenant admin can connect a group.

**Solutions**:

- [Turn on Orchestration](/docs/admin/self-hosting/orchestration#turn-it-on), set `STATEGRAPH_FDW_PROVISIONER_PASSWORD`, and give the `stategraph_provisioner` role that password. See [Database](/docs/admin/self-hosting/orchestration#database).
- For a connected group, continue its setup, or rotate its credentials in the wizard.
- Ask a tenant admin to connect the group.

### GitLab webhook test fails or the installation stays pending

**Symptoms**: In GitLab, **Test > Push events** on the Stategraph webhook returns an error. Or the **Verify Webhook** step of the wizard reports that the webhook is not active yet.

**Causes**:

1. HTTP `400`: the webhook has no secret token.
2. HTTP `500`: the secret token matches no installation, for example because GitLab still sends the old secret after a rotation.
3. No delivery yet: an installation stays `pending` until the first webhook delivery with its secret.

**Solutions**:

- Paste the webhook secret from the wizard into the **Secret token** field of the webhook, then send **Test > Push events** again. With the current secret, the test answers HTTP `200`.
- If the secret is lost, see [Lost the GitLab webhook secret](#lost-the-gitlab-webhook-secret).

### GitLab pipeline does not start

**Symptoms**: After a plan or apply command, the merge request gets an error comment, and no pipeline runs.

**Error message**

```text
Could not start pipeline because the bot account does not have permission to run pipelines.  Its identity must be verified.
```

**Solution**:

- Sign in to GitLab as the bot account whose token Stategraph uses, open **Build > Pipelines** in the project, and complete the identity verification. Then comment `stategraph plan` again.

**Error message**

```text
Unable to start workflow due to missing inputs.
```

Stategraph reports this failure as `GITLAB_INPUTS_MISSING_DEFAULTS`. GitLab refused the pipeline with `Given inputs not defined in the spec section`: the `spec` block of `.gitlab-ci.yml` must declare each input that Orchestration sends, with a default.

**Solution**:

- Declare all four inputs, with defaults, at the top of `.gitlab-ci.yml`:

```yaml
# .gitlab-ci.yml - Stategraph pipeline
spec:
  inputs:
    TERRATEAM_TRIGGER:
      description: "Is this being triggered by Stategraph?"
      type: string
      default: "$TERRATEAM_TRIGGER"
    WORK_TOKEN:
      description: "The work token from Stategraph"
      type: string
      default: "$WORK_TOKEN"
    API_BASE_URL:
      description: "The base url for the Stategraph API"
      type: string
      default: "$API_BASE_URL"
    RUNS_ON:
      description: "The tags to use for the runner"
      type: array
      default: []
---
```

- Keep the include of the Stategraph template below the `---` line. The error comment and the [GitLab quickstart](/docs/get-started/quickstart/cloud#gitlab) contain the full file.

**Error message**

```text
Stategraph failed while dispatching this operation to GitLab CI, so no pipeline job was started.  Nothing was planned or applied.
```

**Solution**:

- On self-managed GitLab, make sure that `terrateam-io/terrateam-template` exists on your instance. GitLab refuses the pipeline when the `.gitlab-ci.yml` include cannot find it.
- Run the command again. If it keeps failing, contact [support](/docs/support) with the request ID from the comment.

### GitLab job fails when it calls back on self-managed GitLab

**Symptoms**: On self-managed GitLab, a plan or apply starts a pipeline, but the job fails when it authenticates to Stategraph.

**Cause**: Stategraph Orchestration requires GitLab 18.1 or later, Community or Enterprise Edition. Each run starts as a pipeline with `inputs`, which carry the work token and the API base URL. GitLab before 17.10 ignores `inputs`, so the job runs without them. On 17.10 to 18.0, it depends on the `ci_inputs_for_pipelines` feature flag. gitlab.com always meets the requirement.

**Solution**:

- Check the instance version with the metadata API, then upgrade to GitLab 18.1 or later. See [GitLab version](/docs/admin/self-hosting/orchestration#gitlab-version).

```bash
curl --header "PRIVATE-TOKEN: <your-token>" \
  "https://gitlab.example.com/api/v4/metadata"
```

### GitLab job failed, or a run never finishes

**Symptoms**: The merge request gets a comment, with a job ID, that a GitLab pipeline job failed. Or a run stays in progress after its GitLab job failed or was canceled.

**Cause**: The CI job ended without posting results. Stategraph learns this from the **Job events** of the webhook. Without them, the run keeps waiting.

**Solutions**:

- Read the log of the named job under **Build > Pipelines** in the project.
- Turn on **Job events** on the project webhook.
- Comment `stategraph plan` or `stategraph apply` to run the operation again.

### Lost the GitLab webhook secret

**Symptoms**: Connecting a GitLab group showed the webhook secret one time, and it was not stored.

**Solution**:

- Rotate the access token and the webhook secret from **Settings > Integrations**, or from the connect wizard for a connected group. Then update the webhook.

### Console signs you out after connecting GitHub or GitLab

**Symptoms**: A completed VCS OAuth flow signs the console user out.

**Cause**: Before 2.5.7, the Orchestration session cookie collided with the console session cookie.

**Solution**:

- Upgrade to 2.5.7 or later. See [Upgrades](/docs/admin/operations/upgrades).
