---
title: Releases & Downloads
description: Install the Stategraph CLI, pull the Stategraph container, verify image signatures, and find the release notes for each version.
order: 6
---


Each Stategraph release has the `stategraph` CLI, as native binaries and a container image, the server container image, and the OpenAPI schema. All releases and their release notes are on the GitHub [releases page](https://github.com/stategraph/releases/releases).

## CLI Installation

Install the CLI with the install script, Homebrew, apt, yum, a [binary download](#binary-downloads), or the [CLI image](#cli).

### Quick install (Linux and macOS)

The script finds your platform and installs the latest release in `/usr/local/bin`:

```bash
curl -fsSL https://get.stategraph.com/install.sh | sh
```

To install without `sudo`, add `--no-sudo`. The script then installs in `~/.local/bin` if it cannot write to `/usr/local/bin`:

```bash
curl -fsSL https://get.stategraph.com/install.sh | sh -s -- --no-sudo
```

### Homebrew (macOS)

```bash
brew tap stategraph/stategraph
brew install stategraph
```

To upgrade, run `brew upgrade stategraph`.

### Debian / Ubuntu (apt)

```bash
curl -fsSL https://stategraph.github.io/releases/apt/KEY.gpg | sudo gpg --dearmor -o /usr/share/keyrings/stategraph-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/stategraph-archive-keyring.gpg] https://stategraph.github.io/releases/apt stable main" | sudo tee /etc/apt/sources.list.d/stategraph.list > /dev/null
sudo apt-get update && sudo apt-get install -y stategraph
```

### RHEL / Fedora / CentOS (yum)

```bash
sudo rpm --import https://stategraph.github.io/releases/yum/KEY.gpg
sudo tee /etc/yum.repos.d/stategraph.repo <<'EOF'
[stategraph]
name=Stategraph
baseurl=https://stategraph.github.io/releases/yum/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://stategraph.github.io/releases/yum/KEY.gpg
EOF
sudo yum install -y stategraph
```

The apt and yum repositories resolve to the latest release, so `apt-get upgrade` or `yum update` keeps the CLI current.

## Container Images

Both images are on GitHub Container Registry.

### Server

Host Stategraph yourself with this image, the Enterprise build. Orchestration is on in the [Docker Compose](/docs/admin/self-hosting/docker-compose) setup. For other deployments, see [Enable Orchestration](/docs/admin/self-hosting/orchestration).

```bash
docker pull ghcr.io/stategraph/stategraph-server:<version>
```

The deployment guides start from this image:

- [Self-hosted overview](/docs/admin/self-hosting): what you need, ports, databases, and optional features
- [Docker Compose](/docs/admin/self-hosting/docker-compose)
- [Kubernetes](/docs/admin/self-hosting/kubernetes)
- [Amazon ECS](/docs/admin/self-hosting/ecs)
- [Cloud Run](/docs/admin/self-hosting/cloud-run)

To move a running deployment to a new version, see [Upgrades](/docs/admin/operations/upgrades). Database migrations run when the new version starts.

### CLI

```bash
docker pull ghcr.io/stategraph/stategraph:<version>
```

The [CLI reference](/docs/cli) shows how to use it, run it from the image, and extract the binary.

### Verifying an image

Release images have a [Sigstore](https://www.sigstore.dev/) keyless signature and a SLSA build provenance attestation. Each per-architecture image also has an SPDX SBOM attestation. The signing certificate records the repository, the release workflow, and the source commit.

Check the signature with [cosign](https://docs.sigstore.dev/cosign/installation/):

```bash
cosign verify \
  --certificate-identity-regexp '^https://github\.com/stategraph/mono/\.github/workflows/release\.yml@' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/stategraph/stategraph:<version>
```

Read the provenance with the same identity:

```bash
cosign verify-attestation --type slsaprovenance1 \
  --certificate-identity-regexp '^https://github\.com/stategraph/mono/\.github/workflows/release\.yml@' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/stategraph/stategraph:<version> \
  | jq -r .payload | base64 -d | jq .predicate
```

The predicate names the builder, the source commit, and the workflow run that produced the image.

With the same identity flags, both commands also accept:

- The server image, `ghcr.io/stategraph/stategraph-server:<version>`.
- The `latest` tag, which has the same digest, and so the same signature, as its version.
- The per-architecture tags `<version>-amd64` and `<version>-arm64`, which have their own signature and provenance.

Read the SBOM, an SPDX list of the packages in the image, from the tag for your architecture:

```bash
cosign verify-attestation --type spdxjson \
  --certificate-identity-regexp '^https://github\.com/stategraph/mono/\.github/workflows/release\.yml@' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/stategraph/stategraph:<version>-amd64 \
  | jq -r .payload | base64 -d | jq .predicate
```

Only the per-architecture tags carry an SBOM. The `<version>` and `latest` tags do not. The server image has its SBOMs on the same tags.

Tags published before image signing started have no signature, and `cosign verify` fails for them. Tags published before SBOM attestations started have no SBOM, and `cosign verify-attestation --type spdxjson` fails for them.

## Binary Downloads

For air-gapped environments or manual installs, download a native binary from the [releases page](https://github.com/stategraph/releases/releases). For most users, the [install script](#quick-install-linux-and-macos) is simpler.

| Platform | Architecture | File |
|----------|--------------|------|
| Linux | x86_64 | `stategraph-<version>-linux-amd64.tar.gz` |
| Linux | ARM64 | `stategraph-<version>-linux-arm64.tar.gz` |
| macOS | Apple Silicon | `stategraph-<version>-macos-arm64.tar.gz` |

Releases no longer include a native Intel macOS binary. Older releases keep their Intel macOS assets.

These commands resolve the latest release, so you have no version to update:

```bash
# Resolve the latest version
VERSION=$(curl -s https://api.github.com/repos/stategraph/releases/releases/latest \
  | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)

# Download and extract (Linux x86_64 shown; swap the suffix for your platform)
curl -LO https://github.com/stategraph/releases/releases/download/$VERSION/stategraph-$VERSION-linux-amd64.tar.gz
tar xzf stategraph-$VERSION-linux-amd64.tar.gz

# Move to PATH and verify
sudo mv stategraph /usr/local/bin/
stategraph --help
```

## API Schema

Use `api.json` from a release for code generation, API clients, and other tools that read OpenAPI specifications. The server also returns it from `GET /api/v1/openapi`. See the [API reference](/docs/reference/api).

## Version Scheme

Stategraph uses [semantic versioning](https://semver.org/):

- Major (X.0.0): breaking changes
- Minor (0.X.0): new features, backwards compatible
- Patch (0.0.X): bug fixes

The CLI and the server share one version line. `stategraph info` prints both, so you can check that they match. See [Utility commands](/docs/cli/utilities).

## Next Steps

- [Editions](/docs/get-started/editions): what each edition includes
