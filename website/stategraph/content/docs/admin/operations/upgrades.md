---
title: Upgrades
description: Upgrade self-hosted Stategraph safely, with start-time migrations, rolling replacement, release changes, and cosign checks.
order: 10
---


To upgrade [self-hosted Stategraph](/docs/admin/self-hosting), run a newer tag of the Stategraph container. It migrates its databases at start, with no separate migration step.

## Pick a version

The [releases page](https://github.com/stategraph/releases/releases) lists versions and notes. In production, pin a version tag, not `latest`:

```yaml
services:
  server:
    image: ghcr.io/stategraph/stategraph-server:2.5.7
```

Then:

- Docker Compose: `docker compose pull` and `docker compose up -d`
- Kubernetes: run `helm upgrade` with the chart `--version` that ships the release, or set `stategraph.image.tag`
- Amazon ECS: set `stategraph_image` and run `terraform apply`
- Google Cloud Run: mirror the new tag into Artifact Registry, update `image:` in the service definition, and redeploy

Releases follow [semantic versioning](https://semver.org/). For the CLI and images, see [Releases](/docs/reference/releases).

## Boot-time migrations

At each start, Stategraph migrates the `stategraph` database, then serves requests. With Orchestration on, it also migrates the `terrateam` database, in parallel and with no order dependency.

- Stategraph checks that the applied migrations are a prefix of its own list. If they differ, it exits non-zero and applies nothing on top.
- Each migration commits by itself, so an interrupted run leaves a consistent prefix, never a partial migration.
- Replicas that migrate at the same time are safe: primary keys guard the bookkeeping rows. The loser of the race fails with a visible duplicate-key error, retries at restart, and never applies a migration twice.
- `/health/ready` answers `502` until Stategraph has migrated and serves, so a load balancer or readiness probe keeps traffic on the old containers. `/health/live` answers `200` as soon as Stategraph listens on port 8080. See [Health checks](/docs/admin/operations/health-checks).
- After a failed Orchestration migration, Stategraph waits 30 seconds before it retries, so retries come at a steady interval with the error in the log.
- A failed Stategraph server restarts every few seconds. In Docker Compose, the container waits for a healthy PostgreSQL through `depends_on`.
- With Orchestration on, the `stategraph` migration also drops and rebuilds the `postgres_fdw` bridge to `terrateam` at each start. On managed PostgreSQL, this needs superuser rights: see [Enable Orchestration](/docs/admin/self-hosting/orchestration).

## Rolling replacement

At stop, Stategraph refuses new requests, finishes those in progress, then shuts down, within a 60 second grace period. Give the container that period: `stop_grace_period: 60s` in Compose, `stopTimeout` of 60 on ECS, or `terminationGracePeriodSeconds: 60` on the pod. Stopping it sooner cuts requests short.

For zero downtime, run several replicas and let readiness control traffic. Set the same `STATEGRAPH_OAUTH_COOKIE_SECRET` on each, so that sessions survive.

## Behavior changes to check

Read the release notes of the versions that you skip. These changes affect running self-hosted deployments:

- Releases after 2.5.8: The Enterprise server checks the license at each start. On a database that has users and no valid license, from `STATEGRAPH_LICENSE_KEY` or entered in the console, it exits with `LICENSE_REQUIRED`, restarts every few seconds, and `/health/ready` answers `502`. A deployment that completed setup with `STATEGRAPH_LICENSE_KEY` must keep the variable set.
- 2.5.7: The container sets `TERRAT_SESSION_COOKIE_NAME=terrat_session`, so the Orchestration session cookie no longer collides with the console `session` cookie. A deployment that replaces the whole container environment must keep it, or a VCS OAuth callback signs console users out.
- 2.5.6: Orchestration does not start when `GITHUB_APP_ID` is set without `GITHUB_WEBHOOK_SECRET`, and no longer accepts unsigned webhook events. A running deployment with GitHub credentials and no secret stops starting Orchestration until you set one. Only the container log shows the failure.
- 2.5.2: The self-hosted setup wizard image moved to `ghcr.io/stategraph/orchestration-setup`.
- 2.5.2: The users API renamed `/api/v1/users/toggle-admin` to `/api/v1/users/set-instance-admin` and the `is_admin` fields to `is_instance_admin`, and added `is_tenant_admin`. Update API clients that create or delete users.

## Verify an image

Released images have a [Sigstore](https://www.sigstore.dev/) keyless signature and a SLSA build provenance attestation. The signing certificate records the repository, release workflow, and source commit. Check it with [cosign](https://docs.sigstore.dev/cosign/installation/) before you run a new tag:

```bash
cosign verify \
  --certificate-identity-regexp '^https://github\.com/stategraph/mono/\.github/workflows/release\.yml@' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/stategraph/stategraph-server:2.5.7
```

Read the provenance with the same identity:

```bash
cosign verify-attestation --type slsaprovenance1 \
  --certificate-identity-regexp '^https://github\.com/stategraph/mono/\.github/workflows/release\.yml@' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/stategraph/stategraph-server:2.5.7 \
  | jq -r .payload | base64 -d | jq .predicate
```

The predicate names the builder, the source commit, and the workflow run that built the image.

- `latest` resolves to the same digest as its version, so both tags check the same signature.
- The per-arch tags `<version>-amd64` and `<version>-arm64` have their own signature and provenance, and both commands accept them with the same identity flags.
- The CLI image, `ghcr.io/stategraph/stategraph`, verifies the same way.
- Tags before 2.5.2 have no signature, and `cosign verify` fails for them.

## Next steps

- [Releases](/docs/reference/releases): downloads, the CLI, and release notes
- [Health checks](/docs/admin/operations/health-checks)
- [Environment variables](/docs/admin/operations/environment-variables)
