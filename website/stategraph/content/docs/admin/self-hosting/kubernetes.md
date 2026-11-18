---
title: Kubernetes
description: Deploy Stategraph Orchestration on Kubernetes with the Helm chart, connect GitHub or GitLab, and set up the ingress, an external PostgreSQL, the health probes, and replicas.
order: 3
---


The [Stategraph Helm chart](https://github.com/stategraph/helm-charts) deploys [Stategraph Orchestration](/docs/admin/self-hosting) on Kubernetes, with an ingress, health probes, and a bundled or external PostgreSQL.

The chart installs the Open Source image, `ghcr.io/stategraph/stategraph-server-oss`. For [Enterprise](/docs/get-started/editions), set `stategraph.edition=enterprise`: the chart then installs `ghcr.io/stategraph/stategraph-server`. Enterprise needs a license key, in `stategraph.license.key` or `stategraph.license.existingSecret`, or entered on the setup screen. Each chart version pins a server release, and `stategraph.image.tag` overrides it.

## Before you begin

- Kubernetes 1.19 or later, Helm 3, and `kubectl` configured for your cluster.
- An ingress controller, for external access.

## Quick start

Install the chart in its own namespace:

```bash
helm repo add stategraph https://stategraph.github.io/helm-charts
helm repo update
helm install stategraph stategraph/stategraph \
  --namespace stategraph \
  --create-namespace
```

For a local trial, forward the service, and create the first admin account on the setup screen at <http://localhost:8080>.

```bash
kubectl port-forward -n stategraph svc/stategraph 8080:80
```

Stategraph Orchestration is on. To connect GitHub or GitLab, Stategraph needs a public HTTPS URL: see [Production installation](#production-installation).

!!! note "Cookie security follows the URL"
    An `https://` URL in `STATEGRAPH_UI_BASE` sets the `Secure` cookie flag, and an `http://` URL does not. So `stategraph.ui.base=http://myserver:8080` allows sign-in over plain HTTP, for a port-forward or an internal network.

## Production installation

Install with HTTPS, an ingress, and a cert-manager issuer:

```bash
helm install stategraph stategraph/stategraph \
  --namespace stategraph \
  --create-namespace \
  --set stategraph.ui.base="https://stategraph.example.com" \
  --set stategraph.ui.oauthRedirectBase="https://stategraph.example.com" \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host="stategraph.example.com" \
  --set ingress.hosts[0].paths[0].path="/" \
  --set ingress.hosts[0].paths[0].pathType="Prefix" \
  --set ingress.tls[0].secretName="stategraph-tls" \
  --set ingress.tls[0].hosts[0]="stategraph.example.com" \
  --set ingress.annotations."cert-manager\.io/cluster-issuer"="letsencrypt-prod"
```

Open `https://stategraph.example.com`, create the first admin account on the setup screen, then [connect GitHub or GitLab](#connect-github-or-gitlab).

## Configuration

`helm show values stategraph/stategraph` lists all chart values. The common ones:

| Value | Description | Default |
|-------|-------------|---------|
| `stategraph.edition` | `oss` or `enterprise`: the server image | `oss` |
| `stategraph.image.repository` | Server image. Empty: the image of the edition | empty |
| `stategraph.image.tag` | Image version, from the [releases page](https://github.com/stategraph/releases/releases) | the chart's `appVersion` |
| `stategraph.replicaCount` | Number of server pods | `1` |
| `stategraph.ui.base` | Public URL (`STATEGRAPH_UI_BASE`) | `http://localhost:8080` |
| `stategraph.ui.oauthRedirectBase` | OAuth callback base (`STATEGRAPH_OAUTH_REDIRECT_BASE`) | unset |
| `stategraph.orchestration.enabled` | Stategraph Orchestration | `true` |
| `postgresql.enabled` | Run the bundled PostgreSQL | `true` |
| `postgresql.auth.existingSecret` | Secret with the database password | `""` |
| `postgresql.persistence.size` | Database volume | `10Gi` |
| `ingress.enabled` | Create an ingress | `false` |

Server settings are [environment variables](/docs/admin/operations/environment-variables) in the `env` list of the `stategraph` container. `helm show values` shows where your chart version puts that list:

```yaml
# values.yaml
env:
  - name: STATEGRAPH_OAUTH_EMAIL_DOMAIN
    value: "example.com"
```

Then roll out the change:

```bash
helm upgrade stategraph stategraph/stategraph -n stategraph -f values.yaml
```

## Using external PostgreSQL

To use your own PostgreSQL server:

```bash
helm install stategraph stategraph/stategraph \
  --namespace stategraph \
  --create-namespace \
  --set postgresql.enabled=false \
  --set postgresql.host="postgres.internal.example.com" \
  --set postgresql.port=5432 \
  --set postgresql.auth.username="stategraph" \
  --set postgresql.auth.existingSecret="external-db-secret"
```

Create the secret with the database password:

```bash
kubectl create secret generic external-db-secret \
  --from-literal=db-password='your-password' \
  -n stategraph
```

Create the `stategraph` database before the first start. For the rights of the database user, see [Databases](/docs/admin/self-hosting#databases). Without `CREATEDB` and `CREATEROLE`, set `stategraph.orchestration.provisionDatabase=false`: the chart's install notes then list the statements to run.

## Authentication

Local email and password sign-in is on by default. For Google or OIDC, set the OAuth values at install:

```bash
helm install stategraph stategraph/stategraph \
  --namespace stategraph \
  --create-namespace \
  --set stategraph.ui.base="https://stategraph.example.com" \
  --set stategraph.ui.oauthRedirectBase="https://stategraph.example.com" \
  --set stategraph.oauth.enabled=true \
  --set stategraph.oauth.type="google" \
  --set stategraph.oauth.clientId="your-client-id" \
  --set stategraph.oauth.clientSecret="your-client-secret"
```

In your provider, register `https://stategraph.example.com/oauth2/google/callback` or `/oauth2/oidc/callback` as the redirect URI. To limit sign-in to your domain, set `STATEGRAPH_OAUTH_EMAIL_DOMAIN`. The chart generates the cookie secret that signs the sign-in, and gives each pod the same value. With `stategraph.oauth.existingSecret`, name its key in `stategraph.oauth.existingSecretKeys.cookieSecret`. See [Access control](/docs/admin/access-control).

## Health checks

The chart sets `livenessProbe` to `/health/live`, which answers `200` when the web server is up, and `readinessProbe` to `/health/ready`, which answers `200` when the server has migrated and serves requests. To change them:

```yaml
# values.yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 10
```

Migrations run before the server starts, so for a large database, allow the readiness probe enough failures. See [Health checks](/docs/admin/operations/health-checks).

## Enable cost estimation

Enterprise only. Set `STATEGRAPH_COST_ENABLED=true` in the container `env`, so that each new or rescheduled pod starts with cost estimation on:

```yaml
# values.yaml
env:
  - name: STATEGRAPH_COST_ENABLED
    value: "true"
```

At the first start, Stategraph loads the price book into the `cloud_pricing` database in the background. Give that database durable storage: the bundled PostgreSQL volume, or your managed server.

Cost estimation connects with `PRICING_DB_*`, not `DB_*`. Its default host is `db`, the Docker Compose service name, so add `PRICING_DB_HOST` and `PRICING_DB_PASSWORD` for your database to the same `env` list. See [Enable cost estimation](/docs/admin/self-hosting/cost).

## Connect GitHub or GitLab

Open **Get Started > Set up your first repository** in the console as the instance admin, and connect GitHub or GitLab. For GitHub, the console creates the GitHub App and stores it, with no change to the values. See [Connect GitHub or GitLab](/docs/admin/self-hosting/orchestration).

To bring a GitHub App that you manage yourself, put its credentials in a secret:

```bash
kubectl create secret generic stategraph-github -n stategraph \
  --from-literal=github-app-id="$GITHUB_APP_ID" \
  --from-literal=github-app-client-id="$GITHUB_APP_CLIENT_ID" \
  --from-literal=github-app-client-secret="$GITHUB_APP_CLIENT_SECRET" \
  --from-literal=github-app-pem="$GITHUB_APP_PEM" \
  --from-literal=github-webhook-secret="$GITHUB_WEBHOOK_SECRET"
```

```bash
helm upgrade stategraph stategraph/stategraph -n stategraph --reuse-values \
  --set stategraph.orchestration.github.existingSecret=stategraph-github \
  --set stategraph.orchestration.github.appUrl="$GITHUB_APP_URL"
```

Then set the webhook URL of the App to `https://stategraph.example.com/api/github/v1/events`.

For GitLab, the secret carries `gitlab-app-id`, `gitlab-app-secret`, and `gitlab-access-token`, and `stategraph.orchestration.gitlab.existingSecret` names it. For self-managed GitLab, also set `stategraph.orchestration.gitlab.apiBaseUrl` and `stategraph.orchestration.gitlab.webBaseUrl` to the root URL of the instance. Then connect each group from the **Get Started** page. The connect wizard shows the project webhook URL, `https://stategraph.example.com/api/v1/gitlab/events`, and the secret.

## Enable security scanning

Enterprise only. Add `STATEGRAPH_SECURITY` with the value `1` to the container `env`. See [Enable security scanning](/docs/admin/self-hosting/security-scanning).

## Upgrading

```bash
helm repo update
helm upgrade stategraph stategraph/stategraph -n stategraph --reset-then-reuse-values
```

`--reset-then-reuse-values` needs Helm 3.14 or later. It keeps the values that you set, and takes the defaults of the new chart. Each chart version pins a server release; to run another one, set `stategraph.image.tag`. From chart 0.2.x, an Enterprise deployment adds `--set stategraph.edition=enterprise`. Chart 0.4.0 turns on Orchestration: on an external PostgreSQL, check the [rights of the database user](#using-external-postgresql) first, or add `--set stategraph.orchestration.enabled=false`. With an earlier Helm, upgrade from 0.3.x with `--reuse-values --set stategraph.orchestration.enabled=true`. See [Upgrades](/docs/admin/operations/upgrades).

## Uninstalling

```bash
helm uninstall stategraph -n stategraph
kubectl delete namespace stategraph
```

## Troubleshooting

```bash
kubectl get pods -n stategraph
kubectl logs -n stategraph -l app.kubernetes.io/name=stategraph
kubectl get events -n stategraph --sort-by='.lastTimestamp'
```

A pod that never becomes ready is usually still migrating, or it failed at start and its log shows why:

- A sign-in provider with a bad configuration.
- No `GITHUB_WEBHOOK_SECRET`.
- A `CONFIG : ERROR` line that names a missing GitLab variable.

## Next steps

- [Import your Terraform state](/docs/infrastructure-as-a-database/import-state)
- [Connect GitHub or GitLab](/docs/admin/self-hosting/orchestration)
- [Observability](/docs/admin/operations/observability)
