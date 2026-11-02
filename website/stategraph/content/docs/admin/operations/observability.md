---
title: Observability
description: Monitor self-hosted Stategraph through its health endpoints, its container log, its access log, and platform metrics.
order: 12
---


Monitor [self-hosted Stategraph](/docs/admin/self-hosting) through its health endpoints, its logs, and the metrics of your platform.

## Health endpoints

Load balancers, probes, and uptime monitoring use `/health/live` and `/health/ready` on port 8080. See [Health checks](/docs/admin/operations/health-checks).

With cost estimation on, `/readyz` on port 8090 inside the container answers `200` when the price book is loaded, and `503` while it loads. See [Enable cost estimation](/docs/admin/self-hosting/cost).

## Logs

Stategraph writes all logs to the container output:

```bash
docker compose logs -f server
kubectl logs -n stategraph -l app.kubernetes.io/name=stategraph -f
aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow
gcloud run services logs read stategraph --region="$REGION" --limit=100
```

The server logs at debug level. A failed start logs the reason:

- a missing or invalid sign-in variable
- a missing `STATEGRAPH_FDW_PASSWORD`
- a missing `GITHUB_WEBHOOK_SECRET`
- a missing GitLab variable
- a `CREATE DATABASE` statement for you to run for Orchestration

If the sign-in provider cannot be set up, the server logs the reason, tries again every second, and accepts no requests until the setup succeeds.

### Access log

The access log is off by default. To write each request to the container log, set [`STATEGRAPH_ACCESS_LOG`](/docs/admin/operations/environment-variables) to `/dev/stdout`:

```bash
# .env
STATEGRAPH_ACCESS_LOG=/dev/stdout
```

## Platform metrics

Your platform gives container CPU, memory, request counts, and latency:

- Amazon ECS: Container Insights, under **Container Insights > ECS Clusters** in the CloudWatch console
- Google Cloud Run: **Cloud Run > stategraph > Metrics** in the Cloud console
- Kubernetes: your cluster's metrics pipeline

## Next steps

- [Health checks](/docs/admin/operations/health-checks)
- [Troubleshooting](/docs/reference/troubleshooting)
