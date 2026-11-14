---
title: AWS OIDC
description: Set up OpenID Connect between GitHub Actions and AWS so Stategraph Orchestration assumes an IAM role without storing long-lived access keys.
order: 2
---

With OpenID Connect (OIDC), the GitHub Actions job that runs your plan assumes an IAM role with a short-lived token from GitHub. You store no AWS access keys in your repository. It is the recommended method for production.

Setup has two steps:

1. Create the OIDC provider and the IAM role in AWS. Do this one time, from your workstation with your own AWS credentials, not through Orchestration.
2. Add an `oidc` hook to `.stategraph/config.yml`.

## Quick setup

Create the provider and the role with Terraform, the AWS CLI, or the AWS Console. For a custom trust policy, use the [manual setup](#manual-setup). In each method, `GITHUB_ORG` is your GitHub organization or user name, and it is case-sensitive.

### Terraform

The [terraform-aws-terrateam-setup](https://github.com/terrateamio/terraform-aws-terrateam-setup) module creates every AWS resource that Orchestration needs. You need Terraform and AWS credentials on your workstation, from the AWS CLI or from environment variables.

1. Create `main.tf`:

```hcl
module "stategraph_aws_setup" {
  source               = "github.com/terrateamio/terraform-aws-terrateam-setup"
  github_org           = "GITHUB_ORG"
  aws_policy_arn       = "arn:aws:iam::aws:policy/PowerUserAccess"
  aws_iam_role_name    = "stategraph"
  create_oidc_provider = true
}
```

2. Apply it:

```bash
terraform apply
```

### AWS CLI

Create a CloudFormation stack from the [setup template](https://terrateam-io-public.s3.us-east-2.amazonaws.com/terrateam-setup-cloudformation.yml):

```bash
aws cloudformation create-stack \
--stack-name stategraph-setup \
--template-url https://terrateam-io-public.s3.us-east-2.amazonaws.com/terrateam-setup-cloudformation.yml \
--parameters ParameterKey=GithubOrg,ParameterValue=GITHUB_ORG \
ParameterKey=RoleArn,ParameterValue=arn:aws:iam::aws:policy/PowerUserAccess \
ParameterKey=CreateGithubOIDCProvider,ParameterValue=true \
ParameterKey=RoleName,ParameterValue=stategraph \
--capabilities CAPABILITY_NAMED_IAM
```

### AWS Console

1. Open **CloudFormation**, choose **Create stack**, and enter this Amazon S3 URL as the template source:

```text
https://terrateam-io-public.s3.us-east-2.amazonaws.com/terrateam-setup-cloudformation.yml
```

2. Set `GithubOrg` (case-sensitive). Set `RoleArn` to `arn:aws:iam::aws:policy/PowerUserAccess`, or to another IAM policy.
3. Keep the default stack options. Orchestration needs none of them.
4. Review and create the stack.

!!! tip "Policy choice"
    `PowerUserAccess` is a starting point. For production, use a custom policy with fewer permissions.

## Configure Orchestration for OIDC

Add an `oidc` hook to `.stategraph/config.yml` at the root of your repository. Replace `AWS_ACCOUNT_ID` with your AWS account ID.

```yaml
hooks:
  all:
    pre:
      - type: oidc
        provider: aws
        role_arn: "arn:aws:iam::AWS_ACCOUNT_ID:role/stategraph"
```

Before each operation, the hook calls `aws sts assume-role-with-web-identity` with the GitHub token. It exports `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` for the rest of the run. For `region`, `duration`, `assume_role_arn`, and the other keys, see the [hooks reference](/docs/reference/orchestration/configuration/hooks).

## Manual setup

Use these steps for a custom configuration, or to see each resource that the quick setup creates.

1. Create the OIDC provider, so that AWS trusts the GitHub identity provider:

```bash
aws iam create-open-id-connect-provider \
--url https://token.actions.githubusercontent.com \
--client-id-list sts.amazonaws.com \
--thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd
```

2. Create `trustpolicy.json` on your workstation. Replace `AWS_ACCOUNT_ID` and `GITHUB_ORG` with your values.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:GITHUB_ORG/*"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

There are example trust policies for [one repository](https://github.com/terrateamio/terrateam-example/blob/main/aws/oidc/trustpolicy/single-repository/trustpolicy.json) and for [more than one repository](https://github.com/terrateamio/terrateam-example/blob/main/aws/oidc/trustpolicy/multiple-repositories/trustpolicy.json). For tighter subject conditions, see [Hardening AWS OIDC](/docs/orchestration/security/hardening-aws-oidc).

3. Create the IAM role with the trust policy:

```bash
aws iam create-role \
--role-name stategraph \
--assume-role-policy-document file://trustpolicy.json
```

4. Attach a permissions policy to the role. `PowerUserAccess` is a starting point. For production, use a custom policy.

```bash
aws iam attach-role-policy \
--policy-arn arn:aws:iam::aws:policy/PowerUserAccess \
--role-name stategraph
```

5. Add the `oidc` hook, as in [Configure Orchestration for OIDC](#configure-orchestration-for-oidc).

## Multiple environments

To use one IAM role per environment, put the `oidc` step in [workflows](/docs/reference/orchestration/configuration/workflows), not in `hooks`. Each workflow selects directories with a `tag_query` and runs its own steps.

```yaml
workflows:
  - tag_query: "terraform/production in dir"
    plan:
      - type: oidc
        provider: aws
        role_arn: "arn:aws:iam::PROD_ACCOUNT_ID:role/stategraph-prod"
      - type: init
      - type: plan
    apply:
      - type: oidc
        provider: aws
        role_arn: "arn:aws:iam::PROD_ACCOUNT_ID:role/stategraph-prod"
      - type: init
      - type: apply
  - tag_query: "terraform/staging in dir"
    plan:
      - type: oidc
        provider: aws
        role_arn: "arn:aws:iam::STAGING_ACCOUNT_ID:role/stategraph-staging"
      - type: init
      - type: plan
    apply:
      - type: oidc
        provider: aws
        role_arn: "arn:aws:iam::STAGING_ACCOUNT_ID:role/stategraph-staging"
      - type: init
      - type: apply
```

The role ARN can also come from a repository secret, as `${AWS_ROLE_ARN}`. For more patterns, see [Cloud credentials](/docs/orchestration/security/cloud-credentials).

## Next Steps

- [Hardening AWS OIDC](/docs/orchestration/security/hardening-aws-oidc): restrict the trust policy to specific repositories, branches, and environments
- [Multi-environment](/docs/orchestration/workflows/advanced/multi-environment): structure directories and workflows per environment
- [Apply requirements](/docs/reference/orchestration/configuration/apply-requirements): require approvals and passing checks before an apply
