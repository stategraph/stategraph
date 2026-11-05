---
title: Self-signed certificates
description: Make Stategraph Orchestration runners and a self-hosted Stategraph server trust the certificates of your private certificate authority.
order: 7
---


To trust a private certificate authority (CA), give the runner the CA certificate in a CI variable, and build a derived image for a self-hosted Stategraph server. Internal services, private module registries, and enterprise proxies often use certificates from a private CA.

## Runner-side trust

At the start of each run, before any Terraform operation, the runner:

- reads each variable whose name starts with `CUSTOM_CA_BUNDLE_`
- writes each certificate that it finds to `/usr/local/share/ca-certificates/`
- runs `update-ca-certificates` to rebuild the system trust store

Terraform, cloud CLIs, `git`, and the other tools in the run then validate TLS connections against these certificates. The runner reads certificates only from the job's variables. An `env` hook in `.stategraph/config.yml` runs too late to install certificates.

### Add the certificate as a CI variable

1. Open your repository settings. On GitHub: **Settings**, **Secrets and variables**, **Actions**, **Variables**. On GitLab: **Settings**, **CI/CD**, **Variables**.
2. Create a variable whose name starts with `CUSTOM_CA_BUNDLE_`, for example `CUSTOM_CA_BUNDLE_CORP` or `CUSTOM_CA_BUNDLE_INTERNAL`. Make it a variable, not a secret: a CA certificate is public.
3. Paste the full PEM content, with the header and footer lines:

```text
-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAKLdQVPy90WjMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
[... certificate content ...]
nI7bfRn4YjSSiXzPuQVh66IYHIvw+xP6
-----END CERTIFICATE-----
```

On GitHub, use a repository, organization, or environment variable. On GitLab, use a project or group CI/CD variable. Set it where the runs need it.

### Multiple certificates

Use one variable for each CA:

```bash
CUSTOM_CA_BUNDLE_CORP="-----BEGIN CERTIFICATE-----..."
CUSTOM_CA_BUNDLE_INTERNAL="-----BEGIN CERTIFICATE-----..."
CUSTOM_CA_BUNDLE_PARTNER="-----BEGIN CERTIFICATE-----..."
```

A variable can also hold several PEM blocks. The runner installs each certificate in each variable.

## Server-side trust on a self-hosted server

The self-hosted Stategraph server does not support the `CUSTOM_CA_CERT` environment variable. Setting it has no effect.

To make the server trust a private CA, for example for GitHub Enterprise Server or a self-hosted GitLab with an internal certificate, build a derived image that adds the CA to the system trust store. For Enterprise, start `FROM ghcr.io/stategraph/stategraph-server:latest`.

```dockerfile
FROM ghcr.io/stategraph/stategraph-server-oss:latest
USER root
COPY internal-ca.pem /usr/local/share/ca-certificates/internal-ca.crt
RUN update-ca-certificates
USER stategraph
```

The image runs as the `stategraph` user, so the build changes to `root` to update the trust store, and then back. Run the derived image in place of the original one. For the deployment guides, see [Self-hosted](/docs/admin/self-hosting).

## Next steps

- [Private runners](/docs/orchestration/security/private-runners): run jobs inside the network that uses the private CA.
- [Environment variables](/docs/admin/operations/environment-variables): the environment reference of a self-hosted server.
