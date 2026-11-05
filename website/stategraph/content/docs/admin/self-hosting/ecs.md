---
title: Amazon ECS
description: Deploy Stategraph on Amazon ECS Fargate with the Terraform module, an Application Load Balancer, and RDS PostgreSQL.
order: 4
---


Deploy [Stategraph](/docs/admin/self-hosting) on Amazon ECS Fargate with the [Stategraph ECS Terraform module](https://github.com/stategraph/terraform-aws-stategraph-ecs).

The examples use the Open Source image, `ghcr.io/stategraph/stategraph-server-oss`. Replace `<version>` with the latest release on the [releases page](https://github.com/stategraph/releases/releases), and `<module version>` with the latest tag of the [module](https://github.com/stategraph/terraform-aws-stategraph-ecs/tags). For [Enterprise](/docs/get-started/editions), set `stategraph_image` to `ghcr.io/stategraph/stategraph-server:<version>`: its setup screen asks for the license key first.

## Before you begin

- Terraform 1.0 or later
- AWS CLI 2 with credentials for ECS, RDS, ALB, IAM, Secrets Manager, and CloudWatch
- A VPC with private and public subnets, or the complete example that creates one
- An ACM certificate for HTTPS
- A domain name for the instance

## Architecture

<figure class="docs-figure">
<div class="docs-why-panel docs-diagram-fit">
<div class="docs-diagram-arch">
<div class="docs-flow-node">Internet</div>
<span class="docs-diagram-link"></span>
<div class="docs-flow-node">Application Load Balancer<small>HTTPS:443</small></div>
<span class="docs-diagram-link"></span>
<div class="docs-flow-node accent">ECS service<small>Fargate tasks in private subnets</small></div>
<div class="docs-diagram-fan"><div><span class="docs-diagram-link"></span><div class="docs-flow-node">RDS PostgreSQL<small>Multi-AZ</small></div></div><div><span class="docs-diagram-link"></span><div class="docs-flow-node">Secrets Manager<small>credentials</small></div></div><div><span class="docs-diagram-link"></span><div class="docs-flow-node">CloudWatch Logs<small>container logs</small></div></div></div>
</div>
</div>
<figcaption>HTTPS requests from the internet reach the Application Load Balancer on port 443.<br> The load balancer sends them to the Fargate tasks of the ECS service, in private subnets.<br> The tasks use Multi-AZ RDS PostgreSQL, Secrets Manager for the credentials, and CloudWatch Logs for the container logs.</figcaption>
</figure>

The module creates the resources in the diagram, and also:

- ECS cluster
- Security groups for the ALB, tasks, and RDS
- IAM roles for the tasks
- Auto scaling policies

## Quick start

### 1. Request an ACM certificate

```bash
aws acm request-certificate \
  --domain-name stategraph.example.com \
  --validation-method DNS \
  --region us-east-1
```

Validate it through DNS as the AWS console instructs, and note its ARN.

### 2. Write the Terraform configuration

```bash
mkdir stategraph-ecs && cd stategraph-ecs
```

```hcl
# main.tf
module "stategraph" {
  source = "github.com/stategraph/terraform-aws-stategraph-ecs?ref=<module version>"

  # Network (your existing VPC)
  vpc_id             = "vpc-xxxxx"
  private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
  public_subnet_ids  = ["subnet-aaaaa", "subnet-bbbbb"]

  # Domain and certificate
  domain_name     = "stategraph.example.com"
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"

  # Image
  stategraph_image = "ghcr.io/stategraph/stategraph-server-oss:<version>"

  environment = "production"

  tags = {
    Project   = "Stategraph"
    ManagedBy = "Terraform"
  }
}

output "alb_dns_name" {
  description = "Create a CNAME record pointing your domain here"
  value       = module.stategraph.alb_dns_name
}

output "database_endpoint" {
  value     = module.stategraph.database_endpoint
  sensitive = true
}
```

### 3. Apply

```bash
terraform init
terraform plan
terraform apply
```

The apply takes 10 to 15 minutes.

!!! note "First startup"
    On the first deploy, migrations run for a few minutes before the server accepts requests. The module configures the ALB target group and the container health check for this window. See [Health checks](/docs/admin/operations/health-checks) for the recommended intervals and grace period.

### 4. Configure DNS

Point your domain at the load balancer with a CNAME, or with a Route 53 alias record and the ALB zone ID:

```bash
terraform output alb_dns_name
terraform output -raw alb_zone_id
```

### 5. Open Stategraph

After DNS propagates, open `https://stategraph.example.com` and create the first admin account on the setup screen. The module sets `STATEGRAPH_UI_BASE` to `https://<domain_name>`, so cookies have the `Secure` flag. Keep `domain_name` in step with the certificate and DNS record.

## Configuration

### Required variables

| Variable | Description | Example |
|----------|-------------|---------|
| `vpc_id` | VPC for every resource | `vpc-xxxxx` |
| `private_subnet_ids` | Private subnets for the tasks and RDS | `["subnet-xxxxx", "subnet-yyyyy"]` |
| `public_subnet_ids` | Public subnets for the ALB | `["subnet-aaaaa", "subnet-bbbbb"]` |
| `domain_name` | Public host name | `stategraph.example.com` |
| `certificate_arn` | ACM certificate for HTTPS | `arn:aws:acm:...` |

### Common optional variables

| Variable | Description | Default |
|----------|-------------|---------|
| `environment` | Environment name | `production` |
| `ecs_task_cpu` | Task CPU units | `1024` |
| `ecs_task_memory` | Task memory in MB | `2048` |
| `ecs_desired_count` | Number of tasks | `2` |
| `enable_autoscaling` | Scale on CPU and memory | `true` |
| `database_instance_class` | RDS instance class | `db.t3.medium` |
| `database_multi_az` | Multi-AZ RDS | `true` |
| `stategraph_image` | Container image: `ghcr.io/stategraph/stategraph-server-oss:<version>` for Open Source | `ghcr.io/stategraph/stategraph-server:latest` |

The module documentation lists every variable. Stategraph settings are [environment variables](/docs/admin/operations/environment-variables) on the server container in the task definition. Reference Secrets Manager secrets in the `secrets` list of the container definition, not in `environment`.

### VPC requirements

- At least two private subnets in different availability zones, for the tasks and RDS
- At least two public subnets in different availability zones, for the ALB
- A NAT gateway or NAT instances for internet access from the private subnets
- DNS hostnames enabled

To create a VPC, use the [terraform-aws-modules/vpc](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest) module, and pass its outputs:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "stategraph-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  enable_dns_hostnames = true
}

module "stategraph" {
  source = "github.com/stategraph/terraform-aws-stategraph-ecs?ref=<module version>"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
  public_subnet_ids  = module.vpc.public_subnets

  # ... other variables
}
```

## Using existing PostgreSQL

Set `create_database = false` and pass the connection details:

```hcl
module "stategraph" {
  source = "github.com/stategraph/terraform-aws-stategraph-ecs?ref=<module version>"

  # ... other required variables

  create_database            = false
  external_database_host     = "postgres.example.com"
  external_database_port     = 5432
  external_database_name     = "stategraph"
  external_database_username = var.database_username
  external_database_password = var.database_password
}
```

The tasks need network access to the database server, and the `stategraph` database must exist before the first start.

## Authentication

Local email and password sign-in is on by default. Turn on Google or OIDC sign-in through the module:

```hcl
module "stategraph" {
  source = "github.com/stategraph/terraform-aws-stategraph-ecs?ref=<module version>"

  # ... other required variables

  oauth_enabled       = true
  oauth_provider      = "google"  # or "oidc"
  oauth_client_id     = var.oauth_client_id
  oauth_client_secret = var.oauth_client_secret

  # For an OIDC provider:
  # oauth_issuer_url = "https://your-provider.example.com"
}
```

In your provider, register the callback URL: `https://stategraph.example.com/oauth2/google/callback` for Google, `https://stategraph.example.com/oauth2/oidc/callback` for OIDC. Keep the client secret in an uncommitted `terraform.tfvars` file or a secrets manager.

The module runs `ecs_desired_count` tasks. Set `STATEGRAPH_OAUTH_COOKIE_SECRET` in the server container environment to the same 16, 24, or 32 character value on each task. Otherwise each task signs cookies with its own random secret, and tasks do not share sessions. See [Access control](/docs/admin/access-control).

## Enable cost estimation

Enterprise only. Set `STATEGRAPH_COST_ENABLED=true` in the server container environment of the task definition, so that each replacement task starts with cost on:

```json
"containerDefinitions": [
  {
    "name": "stategraph",
    "environment": [
      { "name": "STATEGRAPH_COST_ENABLED", "value": "true" }
    ]
  }
]
```

At the first start, Stategraph loads the price book into `cloud_pricing` in the background. Cost estimation connects with `PRICING_DB_*`, not `DB_*`, so point `PRICING_DB_HOST` and `PRICING_DB_PASSWORD` at the RDS instance. See [Enable cost estimation](/docs/admin/self-hosting/cost).

## Enable Orchestration

Stategraph Orchestration is off by default. To turn it on, add `STATEGRAPH_ORCHESTRATION_ENABLED=true` and `STATEGRAPH_FDW_PASSWORD` to the server container environment, with the Orchestration public URLs. Keep the FDW password and each GitHub App or GitLab credential in Secrets Manager. For GitLab, these are `GITLAB_APP_ID`, `GITLAB_APP_SECRET`, `GITLAB_ACCESS_TOKEN`, and `STATEGRAPH_FDW_PROVISIONER_PASSWORD`.

Orchestration needs a second database, `terrateam`, on the RDS instance. The `stategraph` database reads it through `postgres_fdw`, which on Amazon RDS needs the `rds_superuser` role for the database user. [Enable Orchestration](/docs/admin/self-hosting/orchestration) lists the variables and the database steps.

To store a credential, for example the GitHub App private key:

```bash
aws secretsmanager put-secret-value \
  --secret-id <secret-arn> \
  --secret-string file://private-key.pem
```

After you change a secret value, force a new deployment so that tasks read it:

```bash
aws ecs update-service \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --service $(terraform output -raw ecs_service_name) \
  --force-new-deployment
```

Then set the GitHub App webhook URL to `https://stategraph.example.com/api/github/v1/events`. For GitLab, connect each group from the **Get Started** page of the console. Its connect wizard shows the project webhook URL, `https://stategraph.example.com/api/v1/gitlab/events`, and the secret.

## Scaling

To tune auto scaling on CPU and memory:

```hcl
module "stategraph" {
  source = "github.com/stategraph/terraform-aws-stategraph-ecs?ref=<module version>"

  # ... other variables

  enable_autoscaling           = true
  ecs_min_count                = 1
  ecs_desired_count            = 2
  ecs_max_count                = 4
  autoscaling_cpu_threshold    = 70
  autoscaling_memory_threshold = 80
}
```

For a fixed count, set `enable_autoscaling = false` and `ecs_desired_count`. For more headroom per task, raise `ecs_task_cpu` and `ecs_task_memory`, for example to `2048` and `4096`.

## Upgrading

Change the image tag and apply. ECS does a rolling deployment, and the load balancer routes only to tasks that pass the health check:

```hcl
module "stategraph" {
  # ... other variables
  stategraph_image = "ghcr.io/stategraph/stategraph-server-oss:<version>"
}
```

```bash
terraform apply
```

To update the module, change `ref` in `source`, then run `terraform init -upgrade`, `terraform plan`, and `terraform apply`. Give the task an ECS `stopTimeout` of 60 seconds, so that Stategraph can finish requests in progress. See [Upgrades](/docs/admin/operations/upgrades).

## Monitoring

Container logs:

```bash
aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow
```

Service status:

```bash
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name)
```

The module turns on Container Insights. In the CloudWatch console, **Container Insights > ECS Clusters** shows CPU and memory use, target response time, healthy host count, and request count. The database credentials are in Secrets Manager:

```bash
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw database_secret_arn) \
  --query SecretString --output text | jq -r '.password'
```

See [Observability](/docs/admin/operations/observability) for other signals.

## Troubleshooting

Check the container log first:

```bash
aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow
```

- Task stops right after it starts: a secret that the task references is empty, or a required variable is missing. The log says which.
- 502 or 503 from the load balancer, and `502` from `/health/ready`: the task is still migrating. On the first deploy, wait a few minutes.
- Sign-in redirects to the wrong URL: `domain_name` changed. Run `terraform apply` and force a new deployment, so that the tasks read the new `STATEGRAPH_UI_BASE`.

## Next steps

- [Import your Terraform state](/docs/get-started/quickstart/import-state)
- [Enable Orchestration](/docs/admin/self-hosting/orchestration)
- [Gap analysis on AWS resources](/docs/infrastructure-as-a-database/query/gap-analysis)
