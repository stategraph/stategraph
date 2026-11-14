---
title: GCP OIDC
description: Set up Workload Identity Federation so Stategraph Orchestration impersonates a Google Cloud service account from GitHub Actions without a key file.
order: 5
---

With OpenID Connect (OIDC), the GitHub Actions job that runs your plan impersonates a Google Cloud service account with a short-lived token from GitHub, through Workload Identity Federation. You store no service account key in your repository. It is the recommended method for production.

Setup has two steps:

1. Create the workload identity pool, the OIDC provider, and the service account in Google Cloud. Do this one time, from your workstation, not through Stategraph Orchestration.
2. Add an `oidc` hook to `.stategraph/config.yml`.

## Automated setup

Create the resources with Terraform, or with gcloud in the [manual setup](#manual-setup). The [terraform-gcp-terrateam-setup](https://github.com/terrateamio/terraform-gcp-terrateam-setup) module creates every GCP resource that Orchestration needs. You need Terraform and an authenticated gcloud CLI on your workstation.

1. Create `main.tf`. Replace `GITHUB_ORG` with your GitHub organization or user name (case-sensitive), and `PROJECT_ID` with your GCP project ID.

```hcl
module "stategraph_gcp_setup" {
  source                      = "github.com/terrateamio/terraform-gcp-terrateam-setup"
  github_org                  = "GITHUB_ORG"
  project_id                  = "PROJECT_ID"
  service_account_description = "Stategraph service account"
  workload_identity_pool_id   = "stategraph-pool"
  workload_identity_provider  = "stategraph-provider"
  service_account_name        = "stategraph"
  service_account_role        = "roles/editor"
}

output "google_iam_workload_identity_pool_provider_github_provider_name" {
  value = module.stategraph_gcp_setup
}
```

`roles/editor` is a starting point. Replace it with any IAM role that fits your security requirements.

2. Apply it:

```bash
terraform apply
```

3. Save the `google_iam_workload_identity_pool_provider_github_provider_name` output for the next section.

## Configure Orchestration for OIDC

Add an `oidc` hook to `.stategraph/config.yml` at the root of your repository. Replace `PROJECT_ID` with your project ID, and `WORKLOAD_IDENTITY_PROVIDER` with the provider name from the setup output.

```yaml
hooks:
  all:
    pre:
      - type: oidc
        provider: gcp
        service_account: "stategraph@PROJECT_ID.iam.gserviceaccount.com"
        workload_identity_provider: "WORKLOAD_IDENTITY_PROVIDER"
```

Before each operation, the hook exchanges the GitHub token for a short-lived access token of the service account, and exports it as `GOOGLE_OAUTH_ACCESS_TOKEN`. For `access_token_lifetime`, `audience`, and the other keys, see the [hooks reference](/docs/reference/orchestration/configuration/hooks).

## Test the setup

1. Add a small Terraform configuration to your repository.
2. Open a pull request with the change.
3. Comment `stategraph plan` on the pull request.

Orchestration authenticates through Workload Identity Federation and posts the plan on the pull request.

## Manual setup

Use these steps for a custom configuration, or to see each resource that the automated setup creates. Replace `PROJECT_ID` with your project ID, and `GITHUB_ORG` with your GitHub organization or user name (case-sensitive).

1. Create a service account:

```bash
gcloud iam service-accounts create stategraph \
--description="Stategraph service account" \
--display-name="Stategraph" \
--project="PROJECT_ID"
```

2. Create a workload identity pool:

```bash
gcloud iam workload-identity-pools create "stategraph-pool" \
  --project="PROJECT_ID" \
  --location="global" \
  --display-name="Stategraph pool"
```

3. Create the OIDC provider in the pool. The attribute condition limits the provider to the repositories of your organization.

```bash
gcloud iam workload-identity-pools providers create-oidc "stategraph-provider" \
  --project="PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="stategraph-pool" \
  --display-name="Stategraph provider" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == 'GITHUB_ORG'"
```

4. Let identities from the pool impersonate the service account. The binding needs your project number, not the project ID:

```bash
gcloud projects describe PROJECT_ID --format="value(projectNumber)"
```

Replace `PROJECT_NUMBER` with the value it prints.

```bash
gcloud iam service-accounts add-iam-policy-binding "stategraph@PROJECT_ID.iam.gserviceaccount.com" \
  --project="PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/stategraph-pool/attribute.repository_owner/GITHUB_ORG"
```

5. Grant the service account a role on the project. `roles/editor` is a starting point. For production, use a custom or predefined role with fewer permissions.

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
--member="serviceAccount:stategraph@PROJECT_ID.iam.gserviceaccount.com" \
--role='roles/editor'
```

6. Get the full name of the workload identity provider for the Orchestration configuration:

```bash
gcloud iam workload-identity-pools providers describe "stategraph-provider" \
  --project="PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="stategraph-pool" \
  --format="value(name)"
```

7. Add the `oidc` hook, as in [Configure Orchestration for OIDC](#configure-orchestration-for-oidc).

## Multiple environments

To use one service account per environment, put the `oidc` step in [workflows](/docs/reference/orchestration/configuration/workflows), not in `hooks`. Each workflow selects directories with a `tag_query` and runs its own steps.

```yaml
workflows:
  - tag_query: "terraform/production in dir"
    plan:
      - type: oidc
        provider: gcp
        service_account: "stategraph-prod@prod-project.iam.gserviceaccount.com"
        workload_identity_provider: "projects/123456789/locations/global/workloadIdentityPools/stategraph-pool/providers/stategraph-provider"
      - type: init
      - type: plan
    apply:
      - type: oidc
        provider: gcp
        service_account: "stategraph-prod@prod-project.iam.gserviceaccount.com"
        workload_identity_provider: "projects/123456789/locations/global/workloadIdentityPools/stategraph-pool/providers/stategraph-provider"
      - type: init
      - type: apply
  - tag_query: "terraform/staging in dir"
    plan:
      - type: oidc
        provider: gcp
        service_account: "stategraph-staging@staging-project.iam.gserviceaccount.com"
        workload_identity_provider: "projects/123456789/locations/global/workloadIdentityPools/stategraph-pool/providers/stategraph-provider"
      - type: init
      - type: plan
    apply:
      - type: oidc
        provider: gcp
        service_account: "stategraph-staging@staging-project.iam.gserviceaccount.com"
        workload_identity_provider: "projects/123456789/locations/global/workloadIdentityPools/stategraph-pool/providers/stategraph-provider"
      - type: init
      - type: apply
```

For more patterns, see [Cloud credentials](/docs/orchestration/security/cloud-credentials).

## Scoping credentials by environment

In the example above, the service account and the workload identity provider come from your repository configuration. Google cannot tell the environment of a run, so any run that matches the workflow can request any credentials in the configuration.

A [GitHub Environment](/docs/orchestration/security/github-environments) on the workflow closes that gap. GitHub signs the environment into its token, so Google validates the environment and does not have to trust your configuration.

Google recommends [attribute conditions when you federate with GitHub](https://cloud.google.com/iam/docs/best-practices-for-using-workload-identity-federation), and roles for identities that match specific criteria, not for all members of a pool. It also recommends [one pool and one provider for GitHub](https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines), with attributes to separate access.

1. Set the environment on the workflow:

```yaml
workflows:
  - tag_query: "terraform/production in dir"
    environment: production
    plan:
      - type: oidc
        provider: gcp
        service_account: "stategraph-prod@PROJECT_ID.iam.gserviceaccount.com"
        workload_identity_provider: "projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/stategraph-pool/providers/stategraph-provider"
      - type: init
      - type: plan
```

Orchestration runs each environment as its own job, in the GitHub Environment that you name. Create the environment in your repository settings before the first run.

2. Map the environment claim: add `attribute.environment` to the provider from the setup. Replace `PROJECT_ID` and `GITHUB_ORG` with your values.

```bash
gcloud iam workload-identity-pools providers update-oidc "stategraph-provider" \
  --project="PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="stategraph-pool" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.environment=assertion.environment" \
  --attribute-condition="assertion.repository_owner == 'GITHUB_ORG'"
```

A job in an environment also changes the subject claim to `repo:GITHUB_ORG/REPO:environment:production`. Before you roll this out, review each binding that matches on `google.subject`.

3. Bind each service account to its environment. Replace the `attribute.repository_owner` binding from the setup with one binding per environment. Replace `PROJECT_ID` and `PROJECT_NUMBER` with your values.

```bash
gcloud iam service-accounts add-iam-policy-binding "stategraph-prod@PROJECT_ID.iam.gserviceaccount.com" \
  --project="PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/stategraph-pool/attribute.environment/production"
```

A run in the `staging` environment gets a token with `"environment": "staging"`. This token does not satisfy the binding, and Google refuses the impersonation.

### Scoping by workspace

Orchestration sets `TERRATEAM_DIR`, `TERRATEAM_WORKSPACE`, and `TERRATEAM_STACK` before it runs each directory and workspace. The `oidc` step expands them in `service_account`, `workload_identity_provider`, and `audience`.

```yaml
workflows:
  - tag_query: ""
    plan:
      - type: oidc
        provider: gcp
        service_account: "stategraph-${TERRATEAM_WORKSPACE}@PROJECT_ID.iam.gserviceaccount.com"
        workload_identity_provider: "projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/stategraph-pool/providers/stategraph-provider"
      - type: init
      - type: plan
```

The variables resolve only in `plan` and `apply` steps. An `oidc` step under `hooks` runs before a workspace is selected, and it fails if it uses them.

The GitHub token has no workspace claim, so Google cannot verify the workspace. The workspace only selects which service account a run requests. For a boundary that Google enforces, use a GitHub Environment.

## Next Steps

- [GitHub Environments](/docs/orchestration/security/github-environments): associate workflows with GitHub Environments
- [Multi-environment](/docs/orchestration/workflows/advanced/multi-environment): structure directories and workflows per environment
- [Apply requirements](/docs/reference/orchestration/configuration/apply-requirements): require approvals and passing checks before an apply
