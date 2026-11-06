---
title: Stategraph Cloud
description: Sign up for Stategraph Cloud, connect GitHub or GitLab, and get your first plan and apply on a pull request.
order: 2
---


Sign up for Stategraph Cloud, the hosted service, connect GitHub or GitLab, and get your first plan and apply on a pull request. Plans and applies run on your GitHub Actions or GitLab CI runners, not on the server.

## Before you begin

- On GitHub, you must own the organization, or ask an owner to install the app.
- On GitLab, you need a group (personal namespaces are not supported) and admin rights on the tenant. You have them on the tenant that you created.

## Sign up

Go to [app.stategraph.cloud](https://app.stategraph.cloud), sign in, and name your tenant. The name defaults to your account name. A tenant holds your installations, repositories, states, and members, and you administer it.

The Free plan includes every Orchestration feature. Plans differ by usage limits. See [Editions](/docs/get-started/editions).

To import your Terraform state into Infrastructure as a Database, not connect GitHub or GitLab, see [Import your state](/docs/get-started/quickstart/import-state).

## Connect GitHub

In the console, open **Get Started → Set up your first repository → Connect GitHub**, and go to GitHub to install the app.

1. Select the account or organization.
2. Select the repositories that the app can access. **All repositories** also covers ones that you create later.
3. Back in the console, verify with GitHub, and claim your installation to link it to your tenant. The console lists only the unlinked installations in the organizations that GitHub confirms you administer.

Repositories appear in the console after their first pull request event, so the list is empty until you open one.

## Connect GitLab

In the console, open **Get Started → Set up your first repository → Connect GitLab**. The wizard builds every link from the GitLab URL that you enter, so it also works on self-managed GitLab 18.1 or later.

1. Enter the GitLab URL, the group path as it shows in URLs, and the numeric group ID (under the group name, or **Copy group ID** in the group menu).
2. Check the group ID yourself. The wizard does not check it, and a wrong ID gives an installation that never receives webhooks.
3. Enter the project path under the group.
4. Create an access token with the `api` scope, and enter it. Group and project tokens need at least the Developer role.

- Group access token: the narrowest choice, not tied to a person. GitLab Premium or Ultimate on gitlab.com, any tier on self-managed GitLab.
- Project access token: one project.
- Personal access token: any plan, but it stops working if you lose access to the group. Use the classic form, so that you can grant `api`.

Stategraph stores the token write-only. Merge request comments and pipelines for the group run as the user of the token.

5. Add a project webhook in GitLab with the URL and secret token that the wizard shows, and with **Push events**, **Comments**, **Merge request events**, and **Job events** on. Copy the secret before you continue: it shows one time only.
6. Save the webhook, and run **Test → Push events** on it to activate it.
7. In GitLab, set **Settings → CI/CD → Variables → Minimum role to use pipeline variables** to **Developer**, so that Orchestration can use pipeline variables.
8. Push the `.gitlab-ci.yml` that the wizard shows to the repository root on the default branch. See [GitLab](#gitlab).

Later, a tenant admin rotates the access token, the webhook secret, or both in **Settings → Integrations**. A regenerated secret shows one time, and the old one stops working.

## Pick a repository

Enter your repository as `owner/repo` on GitHub, or as `group/repo` or `group/subgroup/repo` on GitLab. The app or the GitLab token must have access to it.

For a first plan with no cloud credentials, use the example repository `stategraph/kick-the-tires`, which uses null resources and local state.

1. Fork it on [GitHub](https://github.com/stategraph/kick-the-tires/fork), into an account or organization where the GitHub App has access, or on [GitLab](https://gitlab.com/terrateam-demo/kick-the-tires/-/forks/new) (gitlab.com only), into the group that you connected.
2. Enter the path of your fork, not the upstream path.
3. On GitHub, enable workflows in the **Actions** tab of the fork. GitHub disables them on a fork that contains workflow files, and the first plan never starts.

<figure class="docs-figure">
<div class="docs-mock">
<div class="docs-mock-tabs"><span>Code</span><span>Pull requests</span><span class="active">Actions</span><span>Settings</span></div><div class="docs-mock-notice"><div class="docs-mock-notice-title">Workflows aren’t being run on this forked repository</div><p>Because this repository contained workflow files when it was forked, we have disabled them from running on this fork. Make sure you understand the configured workflows and their expected usage before enabling Actions on this repository.</p><span class="docs-mock-button">I understand my workflows, go ahead and enable them</span></div>
</div>
<figcaption>On a GitHub fork, open the <strong>Actions</strong> tab and select the button to enable workflows.</figcaption>
</figure>

## Add the workflow file

Orchestration runs plans in your CI. Put the file on the default branch before you open the first pull request, directly or in a pull request that contains only this file. Keep the file names, the action, and the included CI template as shown, because Orchestration depends on them.

### GitHub

Create `.github/workflows/stategraph.yml`:

```yaml
name: 'Stategraph'
on:
  workflow_dispatch:
    inputs:
      # The work-token and api-base-url are passed in by the backend
      work-token:
        description: 'Work Token'
        required: true
      api-base-url:
        description: 'API Base URL'
      environment:
        description: 'Environment in which to run the action'
        type: environment
      runs_on:
        description: 'runs-on configuration'
        type: string
        default: '"ubuntu-latest"'
jobs:
  stategraph:
    permissions: # Required to pass credentials to the action
      id-token: write
      contents: read
    runs-on: ${{ fromJSON(github.event.inputs.runs_on) }}
    timeout-minutes: 1440
    name: Stategraph
    environment: '${{ github.event.inputs.environment }}'
    steps:
      - uses: actions/checkout@v4
      - name: Run Stategraph
        id: stategraph
        uses: terrateamio/action@v1
        with:
          work-token: '${{ github.event.inputs.work-token }}'
          api-base-url: '${{ github.event.inputs.api-base-url }}'
        env:
          SECRETS_CONTEXT: ${{ toJson(secrets) }}
          VARIABLES_CONTEXT: ${{ toJson(vars) }}
```

### GitLab

If you did not push the file from the wizard, create `.gitlab-ci.yml`. The wizard shows the same content:

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
include:
  - project: 'terrateam-io/terrateam-template'
    file: 'terrateam-template.yml'
    inputs:
      TERRATEAM_TRIGGER: $[[ inputs.TERRATEAM_TRIGGER ]]
      WORK_TOKEN: $[[ inputs.WORK_TOKEN ]]
      API_BASE_URL: $[[ inputs.API_BASE_URL ]]
      RUNS_ON: $[[ inputs.RUNS_ON ]]

stages:
  - terrateam

terrateam_job:
  extends: .terrateam_template
```

- If the repository already has a `.gitlab-ci.yml`, merge these jobs into it. In a fork of the example repository, replace its `.gitlab-ci.yml`.
- On self-managed GitLab, the include looks up `terrateam-io/terrateam-template` on your instance. Mirror `gitlab.com/terrateam-io/terrateam-template` to that path first, or pipeline creation fails.
- Orchestration starts the pipeline on the source branch of the merge request, which must also contain `.gitlab-ci.yml`. Create your branch after the file is on the default branch.

### What happens next

- Each directory with `.tf` or `.tfvars` files becomes a root, and each pull request that changes files in a root gets a plan.
- Nothing is applied until someone comments `stategraph apply`.
- `.stategraph/config.yml`, for discovery rules and guardrails, is optional. See [Configuration](/docs/orchestration/configuration).

## Add cloud credentials

Skip this for the example repository. If your Terraform connects to a cloud, add credentials as GitHub secrets or GitLab CI/CD variables, or use OIDC, which stores no long-lived key. The runner reads them at run time. See the guides for [AWS](/docs/orchestration/cloud-providers/aws), [GCP](/docs/orchestration/cloud-providers/gcp), [Azure](/docs/orchestration/cloud-providers/azure), and [other providers](/docs/orchestration/cloud-providers/other).

## Open a pull request

1. Check that the workflow file is on the default branch.
2. Create a branch.
3. Change a `.tf` or `.tfvars` file. In the example repository, change `null_resource_count = 0` to `null_resource_count = 1` in `dev/main.tf`.
4. Open a pull request against the default branch: on a fork, against the fork, not the upstream repository. On GitLab, set the target project of the merge request to your fork.

Orchestration starts the workflow or pipeline on your runner and posts a plan comment with what the change creates, changes, or destroys. **Get Started** in the console shows the progress of the first plan.

On GitHub, the first run may need approval. GitHub marks the run **Action required** and holds it until someone with write access approves it. Open the **Actions** tab, select the run, and select **Approve and run**. This is separate from enabling workflows on a fork.

<figure class="docs-figure">
<div class="docs-mock">
<div class="docs-mock-tabs"><span>Code</span><span>Pull requests</span><span class="active">Actions</span><span>Settings</span></div><div class="docs-mock-notice"><div class="docs-mock-notice-title">Action required</div><p>GitHub detected that this workflow file may be malicious. It will not run until someone with write access approves it. Review the workflow file carefully before approving.</p><span class="docs-mock-button">Approve and run</span></div>
</div>
<figcaption>On GitHub, open the <strong>Actions</strong> tab, select the run, and select <strong>Approve and run</strong>.</figcaption>
</figure>

<figure class="docs-figure" data-vcs="github">
<div class="docs-mock">
<div class="docs-mock-bar"><span class="docs-mock-avatar"><img src="/assets/logo-symbol.svg" alt=""></span><span class="vcs-github docs-mock-author">Stategraph GitHub App</span><span class="vcs-github docs-mock-badge">bot</span><span class="vcs-gitlab docs-mock-author">Access token user</span><span>commented</span><span class="docs-vcs-switch" role="group" aria-label="Provider"><button type="button" data-vcs-set="github" aria-pressed="true">GitHub</button><button type="button" data-vcs-set="gitlab" aria-pressed="false">GitLab</button></span></div><div class="docs-mock-body"><div class="docs-mock-h">Plans 👍</div><p>Outputs can be viewed in the Stategraph Console <span class="docs-mock-link">here</span>.</p><div class="docs-mock-h">Stategraph Plan Output 👍</div><details open><summary>Expand for plan output details</summary><div class="docs-mock-details"><div class="docs-mock-h small">dev | default | Success 👍</div><div class="docs-mock-kv"><div><strong>Dir</strong>: dev</div><div><strong>Workspace</strong>: default</div><div><strong>Success</strong>: 👍</div></div><div class="docs-mock-kv"><div><strong>Step</strong>: tf/plan</div><div><strong>Success</strong>: 👍</div></div><pre>Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # module.dev.null_resource.this[0] will be created
  + resource &quot;null_resource&quot; &quot;this&quot; {
      + id = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.</pre></div></details><hr><p>To apply all these changes, comment:</p><pre>stategraph apply</pre><hr><details><summary><strong>Feedback?</strong></summary><p>Questions? Comments? Give feedback by commenting <code>stategraph feedback &lt;your msg&gt;</code>. Your message lands directly in our inbox.</p></details></div>
</div>
<figcaption>The plan comment for the example repository: one <code>null_resource</code> to create in <code>dev</code>.</figcaption>
</figure>

The plan runs against your branch merged with the current tip of the destination branch, so it shows the result of the merge. Each push plans again. Comment `stategraph plan` to plan on demand, for example if the workflow file was merged after you opened the pull request. Plans are read-only and safe to repeat.

### If no plan starts

- On GitHub, check that GitHub Actions is enabled and that the workflow file is on the default branch.
- On GitHub, check the **Actions** tab for a run marked **Action required**. Select the run and select **Approve and run**.
- On GitLab, check that the source branch contains `.gitlab-ci.yml` and that the minimum role to use pipeline variables is Developer.
- Comment `stategraph repo-config` to see the configuration that Orchestration derived for the repository.
- When a run fails, the pull request comment names the cause. Fix it and comment `stategraph plan`.
- On GitLab, if the cause is identity verification for the user of the token, sign in to GitLab as that user. Complete the verification in **Build → Pipelines** of the project.

## Apply

1. Comment `stategraph apply` on the pull request. Orchestration locks the affected directories, applies the stored plan that you reviewed, and posts the apply output.
2. Merge the pull request. This releases the lock. Until then, another pull request that touches the same directories waits. See [Lock management](/docs/orchestration/workflows/advanced/lock-management).

If another pull request applied an overlapping directory after your plan, the apply aborts with a **Missing Plans** comment. Comment `stategraph plan` again. See [Pull request workflow](/docs/orchestration/workflows).

To apply on merge instead of by comment, add `.stategraph/config.yml` with:

```yaml
when_modified:
  autoapply: true
```

The output then lands on the merged pull request. See [Apply after merge](/docs/orchestration/workflows/apply-after-merge).

Apply requirements gate the `stategraph apply` comment: approvals, no merge conflicts, and passing status checks. See [Apply requirements](/docs/reference/orchestration/configuration/apply-requirements).

## Next steps

- [Configuration](/docs/orchestration/configuration): discovery, workflows, and guardrails.
- [Pull request workflow](/docs/orchestration/workflows): every trigger and its effect.
- [Cloud credentials](/docs/orchestration/security/cloud-credentials): OIDC and secrets for the runner.
- [Import your state](/docs/get-started/quickstart/import-state): scoped plans and resource locks.
- [Pull request commands](/docs/reference/orchestration/commands): all comment commands.
