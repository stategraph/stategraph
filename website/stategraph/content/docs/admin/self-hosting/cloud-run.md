---
title: Google Cloud Run
description: Deploy Stategraph on Google Cloud Run with Cloud SQL for PostgreSQL, the Cloud SQL Auth Proxy sidecar, and Secret Manager.
order: 5
---


Deploy [Stategraph](/docs/admin/self-hosting) as a fully managed Google Cloud Run service, with Cloud SQL for PostgreSQL through a Cloud SQL Auth Proxy sidecar, and Secret Manager for the database password.

## Before you begin

- The `gcloud` CLI, authenticated with `gcloud auth login`
- A Google Cloud project with billing enabled
- Owner or Editor on the project, or the equivalent roles for Cloud Run, Cloud SQL, Secret Manager, and Artifact Registry
- Docker, to mirror the image into Artifact Registry

!!! note "Cloud Run pulls only from Artifact Registry, Container Registry, or Docker Hub"
    Cloud Run does not deploy from `ghcr.io`. Mirror `ghcr.io/stategraph/stategraph-server-oss`, or `ghcr.io/stategraph/stategraph-server` for Enterprise, one time into an Artifact Registry repository in your project, and point the service at the `*-docker.pkg.dev` path.

## Architecture

<figure class="docs-figure">
<div class="docs-why-panel docs-diagram-fit">
<div class="docs-diagram-arch">
<div class="docs-flow-node">Internet<small>HTTPS</small></div>
<span class="docs-diagram-link"></span>
<div class="docs-diagram-group"><span class="docs-diagram-note">Cloud Run service</span><div class="docs-diagram-arch"><div class="docs-flow-node accent">server<small>port 8080</small></div><span class="docs-diagram-link"></span><div class="docs-flow-node">cloud-sql-proxy<small>sidecar on 127.0.0.1:5432</small></div></div></div>
<div class="docs-diagram-fan"><div><span class="docs-diagram-link"></span><div class="docs-flow-node">Cloud SQL for PostgreSQL</div></div><div><span class="docs-diagram-link"></span><div class="docs-flow-node">Secret Manager<small>DB password</small></div></div></div>
</div>
</div>
<figcaption>HTTPS requests from the internet reach the <code>server</code> container on port 8080.<br> The server connects to the <code>cloud-sql-proxy</code> sidecar on <code>127.0.0.1:5432</code>, and the sidecar connects to Cloud SQL for PostgreSQL.<br> The database password comes from Secret Manager.</figcaption>
</figure>

## Quick start

The commands use these shell variables:

```bash
export PROJECT_ID="your-project-id"
export REGION="us-central1"
export INSTANCE="stategraph-db"
export AR_REPO="stategraph"

gcloud config set project "$PROJECT_ID"
gcloud config set run/region "$REGION"
```

### 1. Enable APIs

```bash
gcloud services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  artifactregistry.googleapis.com \
  compute.googleapis.com
```

### 2. Mirror the image into Artifact Registry

```bash
gcloud artifacts repositories create "$AR_REPO" \
  --repository-format=docker \
  --location="$REGION" \
  --description="Stategraph server images"

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

export VERSION="<version>"   # the latest release on https://github.com/stategraph/releases/releases
export IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/stategraph-server-oss:${VERSION}"
docker pull ghcr.io/stategraph/stategraph-server-oss:${VERSION}
docker tag  ghcr.io/stategraph/stategraph-server-oss:${VERSION} "$IMAGE"
docker push "$IMAGE"
```

### 3. Create the Cloud SQL database

```bash
gcloud sql instances create "$INSTANCE" \
  --database-version=POSTGRES_17 \
  --edition=ENTERPRISE \
  --tier=db-custom-1-3840 \
  --region="$REGION" \
  --storage-size=10 \
  --storage-type=SSD

DB_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"
gcloud sql databases create stategraph --instance="$INSTANCE"
gcloud sql users create stategraph --instance="$INSTANCE" --password="$DB_PASSWORD"

export CONNECTION_NAME="$(gcloud sql instances describe "$INSTANCE" --format='value(connectionName)')"
echo "$CONNECTION_NAME"
```

!!! note "Tier and edition"
    `POSTGRES_17` defaults to the Enterprise Plus edition, which rejects the small shared-core tiers. `--edition=ENTERPRISE` allows tiers such as `db-custom-1-3840` (1 vCPU, 3.75 GB), or the shared-core `db-g1-small` for evaluation. Use a larger tier for production.

### 4. Store the database password in Secret Manager

```bash
printf '%s' "$DB_PASSWORD" | gcloud secrets create stategraph-db-pass --data-file=-
```

### 5. Grant the runtime service account access

Cloud Run runs as the project default compute service account, unless you choose another:

```bash
export PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
export RUNTIME_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${RUNTIME_SA}" \
  --role="roles/cloudsql.client" --condition=None

gcloud secrets add-iam-policy-binding stategraph-db-pass \
  --member="serviceAccount:${RUNTIME_SA}" \
  --role="roles/secretmanager.secretAccessor"

gcloud artifacts repositories add-iam-policy-binding "$AR_REPO" \
  --location="$REGION" \
  --member="serviceAccount:${RUNTIME_SA}" \
  --role="roles/artifactregistry.reader"
```

### 6. Write the service definition

Save this as `service.yaml`, with your values for `IMAGE` and `CONNECTION_NAME`:

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: stategraph
  labels:
    cloud.googleapis.com/location: us-central1
spec:
  template:
    metadata:
      annotations:
        # Keep one warm instance: the price-book loader and the scheduled
        # jobs are background work that scale-to-zero would interrupt.
        autoscaling.knative.dev/minScale: "1"
        autoscaling.knative.dev/maxScale: "3"
        # Always allocate CPU so background work runs between requests.
        run.googleapis.com/cpu-throttling: "false"
        run.googleapis.com/startup-cpu-boost: "true"
        # Start the proxy before the server so the database is reachable at boot.
        run.googleapis.com/container-dependencies: '{"server":["cloud-sql-proxy"]}'
    spec:
      containers:
        - name: server
          image: IMAGE
          ports:
            - containerPort: 8080
          env:
            - name: DB_HOST
              value: "127.0.0.1"
            - name: DB_PORT
              value: "5432"
            - name: DB_USER
              value: "stategraph"
            - name: DB_NAME
              value: "stategraph"
            - name: DB_PASS
              valueFrom:
                secretKeyRef:
                  name: stategraph-db-pass
                  key: "latest"
            # Set to the service URL after the first deploy (step 8).
            - name: STATEGRAPH_UI_BASE
              value: "https://REPLACE_WITH_SERVICE_URL"
          # Migrations run at boot; /health/ready returns 502 until they finish.
          startupProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
            failureThreshold: 30
            timeoutSeconds: 5
          resources:
            limits:
              cpu: "1"
              memory: 1Gi
        - name: cloud-sql-proxy
          image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.11.0
          args:
            - "--port=5432"
            - "--health-check"
            - "--http-address=0.0.0.0"
            - "--http-port=9090"
            - "CONNECTION_NAME"
          startupProbe:
            httpGet:
              path: /startup
              port: 9090
            periodSeconds: 5
            failureThreshold: 12
            timeoutSeconds: 3
          resources:
            limits:
              cpu: "1"
              memory: 512Mi
  traffic:
    - percent: 100
      latestRevision: true
```

### 7. Deploy

```bash
gcloud run services replace service.yaml --region="$REGION"
```

The deploy completes when the `server` startup probe passes: `/health/ready` returns `200` after the migrations, and Cloud Run sends no traffic before then. With `failureThreshold: 30` and `periodSeconds: 10`, the migrations have five minutes. For a large database, raise the threshold. See [Health checks](/docs/admin/operations/health-checks).

### 8. Set the public URL and redeploy

Cloud Run assigns the service URL at the first deploy. Set it in `STATEGRAPH_UI_BASE`, which Stategraph uses for links, cookies, and sign-in callbacks:

```bash
export SERVICE_URL="$(gcloud run services describe stategraph --region="$REGION" --format='value(status.url)')"
echo "$SERVICE_URL"

sed -i "s#https://REPLACE_WITH_SERVICE_URL#${SERVICE_URL}#" service.yaml
gcloud run services replace service.yaml --region="$REGION"
```

The Cloud Run URL is always `https://`, so cookies have the `Secure` flag.

### 9. Expose the console

To open the console in a browser, allow unauthenticated access:

```bash
gcloud run services add-iam-policy-binding stategraph \
  --region="$REGION" \
  --member=allUsers \
  --role=roles/run.invoker
```

To keep the service private, skip this step and use an identity token or Identity-Aware Proxy.

!!! note "Domain restricted sharing"
    If your organization enforces `iam.allowedPolicyMemberDomains`, it rejects the `allUsers` binding. Grant the project an `allowAll` override for that constraint, or grant `roles/run.invoker` to specific users or groups.

### 10. Verify the deployment

```bash
curl -sS -o /dev/null -w "live: %{http_code}\n"  "$SERVICE_URL/health/live"
curl -sS -o /dev/null -w "ready: %{http_code}\n" "$SERVICE_URL/health/ready"
```

If the service requires authentication, add an identity token:

```bash
TOKEN="$(gcloud auth print-identity-token)"
curl -sS -H "Authorization: Bearer $TOKEN" \
  -o /dev/null -w "ready: %{http_code}\n" "$SERVICE_URL/health/ready"
```

Open `$SERVICE_URL` and create the first admin account on the setup screen.

## Configuration

The quick start sets the minimum on the `server` container:

- `STATEGRAPH_UI_BASE`: the service URL, for example `https://stategraph-xxxx.us-central1.run.app`, or your custom domain.
- `DB_HOST` and `DB_PORT`: the sidecar, `127.0.0.1:5432`, over TCP, so no database IP is exposed.
- `DB_USER` and `DB_NAME`: `stategraph`.
- `DB_PASS`: the database password, from Secret Manager.

For all other settings, see [Environment variables](/docs/admin/operations/environment-variables).

### Custom domain

Map a domain to the service, then set `STATEGRAPH_UI_BASE` to it and redeploy:

```bash
gcloud run domain-mappings create \
  --service=stategraph \
  --domain=stategraph.example.com \
  --region="$REGION"
```

## Authentication

Local email and password sign-in is on by default. For Google or OIDC, add the OAuth variables to the `server` container. The callback path is `/oauth2/{provider}/callback`, so `STATEGRAPH_OAUTH_REDIRECT_BASE` must equal `STATEGRAPH_UI_BASE`:

```yaml
- name: STATEGRAPH_OAUTH_TYPE
  value: "google"
- name: STATEGRAPH_OAUTH_CLIENT_ID
  value: "your-client-id.apps.googleusercontent.com"
- name: STATEGRAPH_OAUTH_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: stategraph-oauth-secret
      key: "latest"
- name: STATEGRAPH_OAUTH_REDIRECT_BASE
  value: "https://stategraph.example.com"
- name: STATEGRAPH_OAUTH_EMAIL_DOMAIN
  value: "example.com"
```

In your provider, register `https://<your-domain>/oauth2/google/callback` or `/oauth2/oidc/callback`. Keep the client secret in Secret Manager, and grant the runtime service account `roles/secretmanager.secretAccessor` on it, as for the database password. See [Access control](/docs/admin/access-control).

## Enable cost estimation

Enterprise only. Add `STATEGRAPH_COST_ENABLED=true` to the `server` container, and point `PRICING_DB_*` at Cloud SQL. The defaults, host `db` and password `stategraph`, cannot reach it, so with only the switch, cost never works.

```yaml
- name: STATEGRAPH_COST_ENABLED
  value: "true"
# The pricing service reads PRICING_DB_*, not DB_*. Reach Cloud SQL through
# the same sidecar with the same password. PRICING_DB_USER and PRICING_DB_NAME
# already default to stategraph and cloud_pricing.
- name: PRICING_DB_HOST
  value: "127.0.0.1"
- name: PRICING_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: stategraph-db-pass
      key: "latest"
```

At the first start, Stategraph creates the `cloud_pricing` database, because the `gcloud` user has `cloudsqlsuperuser`, which includes `CREATEDB`. It then loads the price book in the background. The price book is in Cloud SQL, so it survives instance replacement. See [Enable cost estimation](/docs/admin/self-hosting/cost).

## Enable Orchestration

Stategraph Orchestration is off by default. To turn it on, add `STATEGRAPH_ORCHESTRATION_ENABLED=true` to the `server` container. Also add the Orchestration public URLs, the FDW role password, and the GitHub App or GitLab credentials from Secret Manager. GitLab also needs `STATEGRAPH_FDW_PROVISIONER_PASSWORD`, so that the console can connect a GitLab group.

Orchestration also needs the `terrateam` database on the same Cloud SQL instance:

- The `gcloud` user has `CREATEDB`, so Orchestration creates it at the first start, owned by the role that it connects as.
- The `stategraph` database reads it through `postgres_fdw`, which on managed PostgreSQL needs superuser rights, or a foreign server and user mapping that you create in advance.
- `STATEGRAPH_FDW_HOST` is the address that the Cloud SQL instance uses to reach `terrateam`, not the sidecar address.

[Enable Orchestration](/docs/admin/self-hosting/orchestration) lists the variables and the roles.

## Scaling

Cloud Run scales on request concurrency, within the revision template bounds:

```yaml
autoscaling.knative.dev/minScale: "1"
autoscaling.knative.dev/maxScale: "3"
```

Keep `minScale` at `1` or higher: scale-to-zero stops the price-book load and the scheduled recomputes. `run.googleapis.com/cpu-throttling: "false"` lets them run between requests. To scale vertically, raise the `server` CPU and memory limits, for example `cpu: "2"` and `memory: 2Gi`.

## Upgrading

Mirror the new tag into Artifact Registry, update `image:` in `service.yaml`, and redeploy:

```bash
export VERSION="<new version>"
docker pull ghcr.io/stategraph/stategraph-server-oss:${VERSION}
docker tag  ghcr.io/stategraph/stategraph-server-oss:${VERSION} "${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/stategraph-server-oss:${VERSION}"
docker push "${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/stategraph-server-oss:${VERSION}"

gcloud run services replace service.yaml --region="$REGION"
```

Cloud Run moves traffic to the new revision when its startup probe passes. See [Upgrades](/docs/admin/operations/upgrades).

## Monitoring

```bash
gcloud run services logs read stategraph --region="$REGION" --limit=100
gcloud run services describe stategraph --region="$REGION"
```

In the Cloud console, **Cloud Run > stategraph > Metrics** shows request count, latency, instance count, CPU, and memory. For other signals, see [Observability](/docs/admin/operations/observability).

## Troubleshooting

### Deploy rejected: invalid image host

**Symptoms**: `gcloud run services replace` fails on the image reference.

**Error message**

```text
Expected an image path like [host/]repo-path[:tag and/or @digest], where host is
one of [region.]gcr.io, [region-]docker.pkg.dev or docker.io
```

**Solution**:

- Cloud Run cannot pull from `ghcr.io`. Mirror the image (step 2), and use the `*-docker.pkg.dev` path

### Cloud SQL instance create fails on tier

**Symptoms**: `gcloud sql instances create` fails at once.

**Error message**

```text
Invalid Tier (db-f1-micro) for (ENTERPRISE_PLUS) Edition
```

**Solution**:

- Add `--edition=ENTERPRISE` and a supported tier. See the note in step 3

### Service stuck starting or readiness never passes

**Symptoms**: the deploy times out, or `/health/ready` keeps returning `502`.

**Solutions**:

1. Check that the runtime service account has `roles/cloudsql.client` and `roles/secretmanager.secretAccessor`
2. Read the `cloud-sql-proxy` container log for a wrong `CONNECTION_NAME` or missing IAM
3. For a large database, raise the `failureThreshold` of the `server` startup probe
4. Read the `server` container log for a sign-in provider error, which stops the start

## Next steps

- [Import your Terraform state](/docs/get-started/quickstart/import-state)
- [Enable Orchestration](/docs/admin/self-hosting/orchestration)
- [Gap analysis on GCP resources](/docs/infrastructure-as-a-database/query/gap-analysis)
