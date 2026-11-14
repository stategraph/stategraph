---
title: Azure OIDC
description: Set up an Entra ID federated credential so Stategraph Orchestration authenticates to Azure from GitHub Actions without a client secret.
order: 8
---

With OpenID Connect (OIDC), the GitHub Actions job that runs your plan authenticates to Azure with a short-lived token from GitHub, through an Entra ID federated credential. You store no client secret in your repository. It is the recommended method for production.

Setup has two steps:

1. Create an App Registration, its service principal, and a federated credential with the Azure CLI. Do this one time, from your workstation, not through Orchestration.
2. Add an `oidc` hook to `.stategraph/config.yml`.

## Prerequisites

- The [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/)
- An Azure subscription with permission to create App Registrations and assign RBAC roles

## Setup

1. Log in to the Azure CLI:

```bash
az login
```

2. Get your subscription ID and tenant ID:

```bash
az account show --query '{subscriptionId:id, tenantId:tenantId}' -o json
```

Output:

```json
{
  "subscriptionId": "00000000-0000-0000-0000-000000000000",
  "tenantId": "00000000-0000-0000-0000-000000000000"
}
```

3. Export the values for the later commands. `GITHUB_ORG` and `REPO_NAME` are case-sensitive.

```bash
export SUBSCRIPTION_ID="<subscription-id>"
export TENANT_ID="<tenant-id>"
export GITHUB_ORG="<github-org-or-username>"
export REPO_NAME="<repository-name>"
```

4. Create an App Registration, and note the `appId` in the output:

```bash
az ad app create --display-name "stategraph"
```

```bash
export CLIENT_ID="<appId>"
```

5. Create a service principal for the App Registration:

```bash
az ad sp create --id "$CLIENT_ID"
```

6. Add a federated credential. First, get the object ID of the App Registration. It is not the same as the client ID.

```bash
APP_OBJECT_ID=$(az ad app show --id "$CLIENT_ID" --query "id" -o tsv)
```

Then create a flexible federated credential through the Microsoft Graph beta API. Its `claimsMatchingExpression` accepts tokens from all branches, tags, and pull requests of your repository.

```bash
az rest --method POST \
  --uri "https://graph.microsoft.com/beta/applications/${APP_OBJECT_ID}/federatedIdentityCredentials" \
  --headers "Content-Type=application/json" \
  --body "{'name': 'stategraph-github', 'issuer': 'https://token.actions.githubusercontent.com', 'audiences': ['api://AzureADTokenExchange'], 'description': 'Stategraph GitHub Actions OIDC', 'claimsMatchingExpression': {'value': 'claims[\'sub\'] matches \'repo:${GITHUB_ORG}/${REPO_NAME}:*\'', 'languageVersion': 1}}"
```

Make sure that the credential exists:

```bash
az rest --method GET \
  --uri "https://graph.microsoft.com/beta/applications/${APP_OBJECT_ID}/federatedIdentityCredentials" \
  --query "value[].{name:name, expression:claimsMatchingExpression.value}" -o table
```

7. Assign an RBAC role to the service principal on your subscription:

```bash
az role assignment create \
  --assignee "$CLIENT_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

`Contributor` is an Azure built-in role. It grants full access to manage resources, but it cannot assign roles in Azure RBAC. Use the role that fits your organization.

### Why claimsMatchingExpression

Orchestration runs on branches and pull requests, so the federated credential must match any ref in your repository. The standard Azure `subject` field needs an exact match, with no wildcards. The `claimsMatchingExpression` property with the `matches` operator accepts the `*` (multi-character) and `?` (single-character) wildcards in the `sub` claim. It is a preview feature, [Flexible Federated Identity Credentials](https://learn.microsoft.com/en-us/entra/workload-id/workload-identities-flexible-federated-identity-credentials).

Other expressions for the `sub` claim:

- `claims['sub'] matches 'repo:org/repo:ref:refs/heads/*'`: any branch only
- `claims['sub'] matches 'repo:org/repo:ref:refs/tags/*'`: any tag only
- `claims['sub'] eq 'repo:org/repo:ref:refs/heads/main'`: one specific branch

## Configure Orchestration for OIDC

Add an `oidc` hook to `.stategraph/config.yml` at the root of your repository. Replace `CLIENT_ID`, `TENANT_ID`, and `SUBSCRIPTION_ID` with your values.

```yaml
hooks:
  all:
    pre:
      - type: oidc
        provider: azure
        client_id: "CLIENT_ID"
        tenant_id: "TENANT_ID"
        subscription_id: "SUBSCRIPTION_ID"
```

Before each operation, the hook gets a GitHub OIDC token with the audience `api://AzureADTokenExchange`. It sets these environment variables, and the Terraform AzureRM and AzAPI providers exchange the token with Entra ID for Azure credentials:

| Variable | Value |
|----------|-------|
| `ARM_USE_OIDC` | `true` |
| `ARM_CLIENT_ID` | Your App Registration client ID |
| `ARM_TENANT_ID` | Your Entra ID tenant ID |
| `ARM_OIDC_TOKEN` | The GitHub OIDC token |
| `ARM_SUBSCRIPTION_ID` | Your Azure subscription ID, when `subscription_id` is set |

For the other keys of the hook, see the [hooks reference](/docs/reference/orchestration/configuration/hooks).

## Test the setup

1. Add a small Terraform configuration to your repository.
2. Open a pull request with the change.
3. Comment `stategraph plan` on the pull request.

Orchestration authenticates through the federated credential and posts the plan on the pull request.

## Multiple environments

To use one App Registration or subscription per environment, put the `oidc` step in [workflows](/docs/reference/orchestration/configuration/workflows), not in `hooks`. Each workflow selects directories with a `tag_query` and runs its own steps.

```yaml
workflows:
  - tag_query: "terraform/production in dir"
    plan:
      - type: oidc
        provider: azure
        client_id: "PROD_CLIENT_ID"
        tenant_id: "TENANT_ID"
        subscription_id: "PROD_SUBSCRIPTION_ID"
      - type: init
      - type: plan
    apply:
      - type: oidc
        provider: azure
        client_id: "PROD_CLIENT_ID"
        tenant_id: "TENANT_ID"
        subscription_id: "PROD_SUBSCRIPTION_ID"
      - type: init
      - type: apply
  - tag_query: "terraform/staging in dir"
    plan:
      - type: oidc
        provider: azure
        client_id: "STAGING_CLIENT_ID"
        tenant_id: "TENANT_ID"
        subscription_id: "STAGING_SUBSCRIPTION_ID"
      - type: init
      - type: plan
    apply:
      - type: oidc
        provider: azure
        client_id: "STAGING_CLIENT_ID"
        tenant_id: "TENANT_ID"
        subscription_id: "STAGING_SUBSCRIPTION_ID"
      - type: init
      - type: apply
```

For more patterns, see [Cloud credentials](/docs/orchestration/security/cloud-credentials).

## Next Steps

- [Multi-environment](/docs/orchestration/workflows/advanced/multi-environment): structure directories and workflows per environment
- [Apply requirements](/docs/reference/orchestration/configuration/apply-requirements): require approvals and passing checks before an apply
- [Azure static credentials](/docs/orchestration/cloud-providers/azure/static-credentials): the client secret alternative
