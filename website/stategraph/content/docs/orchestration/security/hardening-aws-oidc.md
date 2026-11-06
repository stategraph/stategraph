---
title: Hardening AWS OIDC
description: Lock down the AWS IAM trust policy so that only workflow runs dispatched by Stategraph Orchestration can assume your cloud roles.
order: 3
---


Four layers make sure that only runs that Stategraph Orchestration dispatches can assume your AWS roles: three conditions in the IAM trust policy, on the claims of the GitHub Actions OIDC token, and access control that blocks runs for pull requests that change the CI configuration.

The default AWS OIDC trust policy scopes access by repository. A policy that matches only `repo:ORG/REPO:*` trusts every workflow and every trigger in the repository: any workflow in it can get an OIDC token and assume the role. A pull request that adds a workflow file, or edits the existing one, can assume the role and read the credentials. Each layer below adds a stronger condition.

## Layer 1: Restrict to the Orchestration workflow

With GitHub's `job_workflow_ref` claim, only the workflow file that Orchestration dispatches can assume the role. AWS denies each other workflow file in the repository.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:ORG/REPO:*",
          "token.actions.githubusercontent.com:job_workflow_ref": "ORG/REPO/.github/workflows/stategraph.yml@*"
        }
      }
    }
  ]
}
```

!!! warning "Editing the workflow still works"
    This does not stop someone from editing `.github/workflows/stategraph.yml` to add steps. The edited workflow still matches `job_workflow_ref`. Layers 2 and 3 close that gap.

## Layer 2: Restrict to Orchestration-dispatched runs

The `actor` claim of the GitHub OIDC token is the user or app that started the workflow. When Orchestration dispatches your workflow, the actor is its GitHub App: the App slug, followed by `[bot]`. On Stategraph Cloud, that is the Stategraph GitHub App. On a self-hosted deployment, it is the App that you created. The Actions tab shows the actor of each dispatched run.

Add `actor`, `repository`, and `workflow` conditions. `workflow` is the `name` field at the top of the workflow file.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:actor": "APP_SLUG[bot]",
          "token.actions.githubusercontent.com:repository": "ORG/REPO",
          "token.actions.githubusercontent.com:workflow": "WORKFLOW_NAME"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:ORG/REPO:*"
        }
      }
    }
  ]
}
```

If someone dispatches the workflow by hand or adds a new one, the actor is their GitHub username, and AWS rejects the token.

## Layer 3: Enterprise access control

!!! tip "Enterprise feature"
    `ci_config_update` and `terrateam_config_update` are available in the Enterprise edition. See [Editions](/docs/get-started/editions).

With a strict trust policy, a pull request can still edit the CI configuration file to add steps. Two [access control](/docs/reference/orchestration/configuration/access-control) rulesets block such pull requests:

```yaml
access_control:
  enabled: true
  ci_config_update: ['team:infra-admins']
  terrateam_config_update: ['team:infra-admins']
```

| Setting | Protects | Effect |
| --- | --- | --- |
| `ci_config_update` | `.github/workflows/stategraph.yml` on GitHub, `.gitlab-ci.yml` on GitLab | Blocks operations on pull requests that change the CI configuration file unless the author matches the ruleset |
| `terrateam_config_update` | `.stategraph/config.yml` | Blocks operations on pull requests that change the Orchestration configuration unless the author matches the ruleset |

`terrateam_config_update` also covers the legacy `.terrateam/config.yml` path.

### Additional hardening

For defense in depth, add file-level access control and branch protection. Each key under `files` is an exact file path, so list each file that runs with credentials, such as a credential script that your workflow sources:

```yaml
access_control:
  enabled: true
  ci_config_update: ['team:infra-admins']
  terrateam_config_update: ['team:infra-admins']
  files:
    'generate-aws-credentials.sh': ['team:infra-admins']
```

On GitHub, add a [`CODEOWNERS`](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) entry and a branch protection rule for `.github/workflows/`. On GitLab, add a `CODEOWNERS` entry for `.gitlab-ci.yml`, and protect the default branch. See [CODEOWNERS](/docs/orchestration/configuration/codeowners).

## Layer 4: Custom OIDC subject claims

AWS supports only some JWT claims as IAM condition keys. `event_name`, `runner_environment`, and `repository_visibility` are in the GitHub OIDC token, but you cannot use them directly. See the [AWS list of supported keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_iam-condition-keys.html#condition-keys-wif).

GitHub lets you [customize the `sub` claim](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect#customizing-the-subject-claims) to include those values, so that the `sub` condition can enforce them.

### Customize the subject claim

With the GitHub CLI:

```bash
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/ORG/REPO/actions/oidc/customization/sub \
  --input - <<< '{
  "use_default": false,
  "include_claim_keys": [
    "repo",
    "context",
    "event_name",
    "repository_visibility",
    "runner_environment"
  ]
}'
```

### Update the trust policy

With the customized `sub` claim, the trust policy can require all of these conditions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:actor": "APP_SLUG[bot]",
          "token.actions.githubusercontent.com:workflow": "WORKFLOW_NAME",
          "token.actions.githubusercontent.com:repository": "ORG/REPO"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:ORG/REPO:ref:*:event_name:workflow_dispatch:repository_visibility:private:runner_environment:self-hosted"
        }
      }
    }
  ]
}
```

This policy accepts a token only when:

- The GitHub App dispatched the run (`actor`).
- The named workflow runs (`workflow`).
- The event is `workflow_dispatch`, not a manual or other trigger.
- The repository is private.
- The runner is self-hosted.

## Summary

| Layer | Control | What it prevents |
| --- | --- | --- |
| 1 | `job_workflow_ref` in the trust policy | Other workflow files assuming the role |
| 2 | `actor` in the trust policy | Manual or non-Orchestration dispatches |
| 3 | Enterprise `ci_config_update` | Unauthorized edits to the CI configuration file |
| 4 | Custom `sub` claim | Runs from other events, public repositories, or GitHub-hosted runners |

Use all four layers together. Layers 1, 2, and 4 are available in every edition.

## Next steps

- [Cloud credentials](/docs/orchestration/security/cloud-credentials): the `oidc` step and its keys.
- [AWS OIDC setup](/docs/orchestration/cloud-providers/aws/oidc): create the identity provider and role.
- [Private runners](/docs/orchestration/security/private-runners): the `runner_environment:self-hosted` condition needs one.
