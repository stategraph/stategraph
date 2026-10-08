# syntax=docker/dockerfile:1.6
# Enables `RUN --mount=type=cache` (used below to persist dune's _build/
# across image builds). BuildKit >= 1.2 supports it, but pinning the
# syntax frontend keeps us off the daemon's stock parser.

# See the accompanying README.md for documentation

# Global ARG: must be declared before any FROM to use in dynamic FROM instructions. It must have a default value.
ARG DEPLOYMENT_KIND=development

FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS base-tenv-tofu
# Cache-mount id for dune's shared /dune-cache _build store. Bump this one
# constant to abandon a corrupted cache.
ARG DUNE_CACHE_ID=dune-cache-2

# The minirootfs lags its own package branch, so upgrade what it pre-installed.
RUN apk upgrade --no-cache

ARG UID
ARG GID
ARG USERNAME

# Packages needed for installing tenv, tofu (bash, ca-certificates, curl), DuckDB (libstdc++), and checkov (python)
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    libstdc++ \
    py3-pip \
    python3

RUN addgroup -g ${GID} ${USERNAME}
RUN adduser -D -u ${UID} -G ${USERNAME} -s /bin/bash ${USERNAME}

USER root
# Pin tofu's install location to a fixed, system-wide root instead of the build
# user's $HOME/.tenv, so resolution does not depend on the runtime user's home
# matching the build user's. TENV_ROOT is honored at build time (the install
# below) and inherited at runtime by every stage built FROM this one.
ENV TENV_ROOT=/opt/tenv
ENV TENV_VERSION=v4.4.0
# First, we map to Debian-like architecture name
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/') && \
    APK_FILE="tenv_${TENV_VERSION}_${ARCH}.apk" && \
    RELEASE_URL="https://github.com/tofuutils/tenv/releases/download/${TENV_VERSION}" && \
    curl -OL "${RELEASE_URL}/${APK_FILE}" -OL "${RELEASE_URL}/tenv_${TENV_VERSION}_checksums.txt" && \
    grep "$(sha256sum "${APK_FILE}")" "tenv_${TENV_VERSION}_checksums.txt" && \
    apk add --allow-untrusted "${APK_FILE}" && \
    rm -f "${APK_FILE}" "tenv_${TENV_VERSION}_checksums.txt"

# This version number is also used in .github/workflows/test-macos.yml. Update both simultaneously.
ENV TOFU_VERSION=1.11.14
# Run tenv as the user so it installs with the correct permissions. The user
# owns TENV_ROOT so the install can write there.
RUN mkdir -p ${TENV_ROOT} && chown ${USERNAME}:${USERNAME} ${TENV_ROOT}
USER ${USERNAME}
RUN tenv tofu install ${TOFU_VERSION}
USER root

# checkov is a Python app with no static musl binary, so we install the pinned, sha256-verified
# wheel into a dedicated venv and symlink it onto PATH. Only the checkov wheel
# itself is pinned + verified here; its deps (all available as musl wheels) are
# resolved by pip from PyPI. Bumping CHECKOV_VERSION means re-capturing CHECKOV_SHA256
# (the py3-none-any wheel's sha256, e.g. from `pip download` or PyPI's JSON API)
# If you update this location, edit .github/workflows/test-macos.yml too
ENV CHECKOV_VERSION=3.3.16
RUN CHECKOV_SHA256="43e5383418a8b52d39747e2daaec4da4a6b7db3e2f64ab6c93f8b89c044c7665" && \
    python3 -m venv /opt/checkov-venv && \
    /opt/checkov-venv/bin/pip download --no-deps --only-binary=:all: --no-cache-dir \
      -d /tmp/checkov-dl "checkov==${CHECKOV_VERSION}" && \
    echo "${CHECKOV_SHA256}  /tmp/checkov-dl/checkov-${CHECKOV_VERSION}-py3-none-any.whl" | sha256sum -c - && \
    /opt/checkov-venv/bin/pip install --no-cache-dir "/tmp/checkov-dl/checkov-${CHECKOV_VERSION}-py3-none-any.whl" && \
    ln -s /opt/checkov-venv/bin/checkov /usr/local/bin/checkov && \
    rm -rf /tmp/checkov-dl && \
    checkov --version

# The FOCUS billing ETL: the DuckDB CLI, its extensions and the loader. It is an
# enterprise feature, so it gets its own stage rather than a place in
# base-tenv-tofu, which both editions start from. stategraph-dev (for
# Sgs_test_focus_sync) and stategraph-server-ee copy it from here.
FROM base-tenv-tofu AS focus-etl

ARG USERNAME

# DuckDB CLI for the FOCUS billing ETL (code/src/focus_etl).
ENV DUCKDB_VERSION=v1.5.3
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/') && \
    case "${ARCH}" in \
      amd64) DUCKDB_SHA256="fe6dcb7c259ee8f6ecc0fd72ed0f9ce26d5539cc8d1e141c0b95e2168fd0ff16" ;; \
      arm64) DUCKDB_SHA256="1a587a0a8b4d8b9886facccc027a003d9bad1e5236e168fb0f6d39886eb4db63" ;; \
      *) echo "unsupported arch: ${ARCH}" >&2; exit 1 ;; \
    esac && \
    curl -fsSL -o /tmp/duckdb.gz "https://github.com/duckdb/duckdb/releases/download/${DUCKDB_VERSION}/duckdb_cli-linux-${ARCH}-musl.gz" && \
    echo "${DUCKDB_SHA256}  /tmp/duckdb.gz" | sha256sum -c - && \
    gunzip -c /tmp/duckdb.gz > /usr/local/bin/duckdb && \
    chmod 755 /usr/local/bin/duckdb && \
    rm -f /tmp/duckdb.gz && \
    duckdb -c "SELECT version();"

# Pre-bake the ETL's DuckDB extensions into a fixed, world-readable directory so
# the ETL never reaches out to extensions.duckdb.org at runtime (it runs as
# ${USERNAME} and only LOADs). The trailing LOAD is a build-time smoke test.
ENV DUCKDB_EXTENSION_DIR=/usr/local/share/duckdb/extensions
RUN mkdir -p "$DUCKDB_EXTENSION_DIR" && \
    duckdb -c "SET extension_directory='$DUCKDB_EXTENSION_DIR'; \
      INSTALL httpfs; INSTALL aws; INSTALL azure; INSTALL postgres; \
      LOAD httpfs; LOAD aws; LOAD azure; LOAD postgres;" && \
    chmod -R a+rX "$DUCKDB_EXTENSION_DIR"

# FOCUS billing ETL loader (code/src/focus_etl). A self-contained Python script
# (imports the duckdb library installed above) invoked per-source by the
# Sgs_focus_sync worker.
COPY --chown=${USERNAME}:${USERNAME} --chmod=755 code/src/focus_etl/load-focus-billing /usr/local/bin/load-focus-billing

FROM base-tenv-tofu AS base

# region:apk-base
RUN apk add --no-cache \
    bash \
    brotli-static \
    bsd-compat-headers \
    ca-certificates \
    cargo \
    clang \
    cmake \
    coreutils \
    curl \
    curl-dev \
    curl-static \
    git \
    gmp-dev \
    gmp-static \
    go \
    jq \
    libffi-dev \
    libidn2-static \
    libpsl-static \
    libretls \
    libretls-dev \
    libssh2-dev \
    libssh2-static \
    libunistring \
    libunistring-static \
    libuv \
    libuv-dev \
    libuv-static \
    m4 \
    make \
    mercurial \
    musl-dev \
    nghttp2-dev \
    nghttp2-static \
    nghttp3-dev \
    nghttp3-static \
    npm \
    opam \
    openssh \
    openssl-libs-static \
    perl \
    pkgconf \
    py3-yaml \
    python3 \
    rsync \
    rust \
    sqlite-dev \
    wget \
    zlib-dev \
    zlib-static \
    zstd-dev \
    zstd-static
# endregion:apk-base

# Development-specific base extensions
FROM base AS base-development

ARG USERNAME
RUN apk add --no-cache \
    age \
    fd \
    github-cli \
    patch \
    postgresql-client \
    ripgrep \
    sudo \
    tree \
    yq
# Give the user root access. Handy for debugging.
RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Development and containerized development did not differ yet
FROM base-development AS base-devcontainer
# Production base (no additional packages needed)
FROM base AS base-production

# Join all three kinds, restart doing things in common
ARG DEPLOYMENT_KIND
FROM base-${DEPLOYMENT_KIND} AS ocaml-sandbox

ARG USERNAME
USER ${USERNAME}
ENV HOME=/home/${USERNAME}

# region:opam-init
WORKDIR /tmp
# The opam-repository index is fetched once here.
# When this layer is reused cached, new packages may seem missing.
# When you hit that (package published on more recent opam snapshot), bump the date here to re-run this layer.
# Note that the date has no impact on `opam`. It's just a mean to trigger rebuilding of this layer.
ARG OPAM_INDEX_DATE=2026-09-08
RUN echo "opam-repository index refreshed ${OPAM_INDEX_DATE}" && \
    opam init -ay --disable-sandboxing --bare
# endregion:opam-init

# Copy only things required for building the OCaml sandbox
COPY --chown=${USERNAME}:${USERNAME} ./opam mono/opam
COPY --chown=${USERNAME}:${USERNAME} ./vendor/cohttp mono/vendor/cohttp
COPY --chown=${USERNAME}:${USERNAME} ./vendor/ISO8601 mono/vendor/ISO8601

# region:opam-switch
RUN eval $(opam env) && \
    opam switch create -y 5.5.1 && \
    eval $(opam env) && \
    opam repository add opam-acsl mono/opam && \
    opam pin add -n ISO8601 mono/vendor/ISO8601 --no-depexts && \
    opam pin add -n cohttp mono/vendor/cohttp --no-depexts
# endregion:opam-switch

FROM ocaml-sandbox AS ocaml-sandbox-development-or-devcontainer

# Development or devcontainer: install ocamlformat
# region:ocamlformat
RUN eval $(opam env) && opam pin add -y ocamlformat 0.29.0
# endregion:ocamlformat

FROM ocaml-sandbox-development-or-devcontainer AS ocaml-sandbox-devcontainer

# Containerized development: install LSP, claude, depot, and ytt
RUN eval $(opam env) && opam install -y ocaml-lsp-server.1.27.0 dot-merlin-reader.5.8.1-505
# Keep the version in sync with COGAPP_VERSION in .github/workflows/actionlint.yml.
RUN python3 -m pip install --user --break-system-packages --no-cache-dir "cogapp==3.6.0"
RUN bash -c "curl -fsSL https://claude.ai/install.sh | bash" && \
      mkdir -p "$HOME/.claude" && \
      cat > "$HOME/.claude/settings.json" <<'EOF'
{
  "skipDangerousModePermissionPrompt": true,
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
EOF

RUN DEPOT_INSTALL_DIR="$HOME/.local/bin" bash -c "curl -fsSL https://depot.dev/install-cli.sh | sh" && \
      "$HOME/.local/bin/depot" --version

# ytt lands in $HOME/.local/bin (like depot above, and already on PATH via .profile)
# because this stage runs as ${USERNAME}, who cannot write /usr/local/bin.
# Keep the version and amd64 checksum in sync with YTT_VERSION / YTT_SHA256
# in .github/workflows/lint.yml.
ENV YTT_VERSION=0.55.1
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/') && \
    case "${ARCH}" in \
      amd64) YTT_SHA256="3a2c925ed222f8db4956946d40279688edd6ceb3e919f03f919a8fc8b8532eda" ;; \
      arm64) YTT_SHA256="ce61f7aee3f66f9b78d5781ef8528b7c8e199a2747796ef17a954118d3e65724" ;; \
      *) echo "unsupported arch: ${ARCH}" >&2; exit 1 ;; \
    esac && \
    cd /tmp && \
    curl -fsSL -O "https://github.com/carvel-dev/ytt/releases/download/v${YTT_VERSION}/ytt-linux-${ARCH}" && \
    echo "${YTT_SHA256}  ytt-linux-${ARCH}" | sha256sum -c - && \
    install -D -m 755 "ytt-linux-${ARCH}" "$HOME/.local/bin/ytt" && \
    rm -f "ytt-linux-${ARCH}" && \
    "$HOME/.local/bin/ytt" version

# Join all three kinds, restart doing things in common
FROM ocaml-sandbox-development-or-devcontainer AS ocaml-sandbox-development
FROM ocaml-sandbox AS ocaml-sandbox-production

FROM ocaml-sandbox-${DEPLOYMENT_KIND} AS ocaml-deps

# opam.pins is the authoritative list of opam packages the stategraph build
# needs, one `<name>.<version>` per line - the shape `opam install` accepts as-is.
COPY --chown=${USERNAME}:${USERNAME} ./code/opam.pins /tmp/mono/code/

# region:opam-install
RUN eval $(opam env) && cd mono/code && \
    opam install -j$(nproc --all) -y --no-depexts dune.3.24.2 menhir && \
    cat opam.pins | xargs opam install -j$(nproc --all) -y --no-depexts
# endregion:opam-install

WORKDIR /home/${USERNAME}
ENV HOME=/home/${USERNAME}

# Shell environment setup: put everything in .profile (sourced by login shells),
# then have .bashrc source .profile so interactive non-login shells get it too.
RUN cat >> .profile <<'EOF'
export MAKEFLAGS=-j$(nproc)
export PATH+=":$HOME/.local/bin:/tmp/mono/bin"

eval $(opam env)
EOF

RUN echo '. ~/.profile' >> .bashrc

# For non-interactive bash (e.g. docker compose exec ... bash -c '...'):
ENV BASH_ENV=/home/${USERNAME}/.bashrc

WORKDIR /tmp/mono
ENTRYPOINT ["/bin/bash"]

FROM ocaml-deps AS stategraph-pricing-code

ARG USERNAME

# dune-project lives at the repo root and the top-level dune restricts
# scanning to (dirs code api_schemas docker scripts); both must be present before any
# dune build runs.
COPY --chown=${USERNAME}:${USERNAME} ./dune-project ./dune /tmp/mono/
COPY --chown=${USERNAME}:${USERNAME} ./api_schemas /tmp/mono/api_schemas
COPY --chown=${USERNAME}:${USERNAME} ./scripts/check_migrations_registered.sh /tmp/mono/scripts/check_migrations_registered.sh
COPY --chown=${USERNAME}:${USERNAME} ./code/Makefile ./code/dune ./code/dune.stategraph.inc /tmp/mono/code/
COPY --chown=${USERNAME}:${USERNAME} ./code/src/pricing_service /tmp/mono/code/src/pricing_service

FROM stategraph-pricing-code AS stategraph-pricing-development

ARG USERNAME
ARG DUNE_CACHE_ID

# Builds the Go pricing-service so it ships in stategraph-dev (for CI cost
# tests) as well as the production image. Mirrors the cache pattern of the
# main `make -C code stategraph` step below: a BuildKit cache for dune's
# _build/ plus a Go cache for module/build artifacts. `cp -aT` (not `cp -a`)
# replaces the destination tree atomically -- otherwise a second build step
# would nest into /tmp/mono/_build/_build.
#
# `sharing=locked` on /dune-cache: BuildKit cache mounts default to
# `sharing=shared`, which hands concurrent builds the same directory. Our
# restore/save is `cp -aT` over a whole tree with `rm -rf` in front of it,
# which is not safe against a second build doing the same thing -- one build's
# `rm -rf` races the other's `cp`, and dune's read-only outputs then surface as
# "Permission denied"/"File exists". All builds share one Depot builder, so
# concurrent PRs collide routinely. `locked` serializes them.
RUN --mount=type=cache,id=${DUNE_CACHE_ID},target=/dune-cache,uid=1000,gid=1000,sharing=locked \
    --mount=type=cache,target=/go-cache,uid=1000,gid=1000 \
    eval $(opam env) && \
    export PATH="$PATH:$HOME/.local/bin" && \
    export GOMODCACHE=/go-cache/mod GOCACHE=/go-cache/build && \
    if [ -d /dune-cache/_build ]; then \
      mkdir -p /tmp/mono/_build && \
      cp -aT /dune-cache/_build /tmp/mono/_build; \
    fi && \
    cd /tmp/mono && \
    dune build code/src/pricing_service/pricing-service && \
    rm -rf /dune-cache/_build && \
    cp -aT /tmp/mono/_build /dune-cache/_build

# Production uses the same pricing build as development
FROM stategraph-pricing-development AS stategraph-pricing-production
# Devcontainer skips the pricing build to keep image creation quick.
FROM stategraph-pricing-code AS stategraph-pricing-devcontainer

ARG DEPLOYMENT_KIND
FROM stategraph-pricing-${DEPLOYMENT_KIND} AS stategraph-pricing

# Resume with the UI code stages, layered on top of the pricing build.
FROM stategraph-pricing AS stategraph-ui-code

ARG USERNAME

COPY --chown=${USERNAME}:${USERNAME} ./code/src/hermes /tmp/mono/code/src/hermes

FROM stategraph-ui-code AS stategraph-ui-development

RUN eval $(opam env) && dune build @code/hermes

# Both in production and development builds, we want the UI to be built
FROM stategraph-ui-development AS stategraph-ui-production
# In the dev container setup, however, we don't need the UI code to be built
FROM stategraph-ui-code AS stategraph-ui-devcontainer

# Join all three kinds, restart doing things in common
ARG DEPLOYMENT_KIND
FROM stategraph-ui-${DEPLOYMENT_KIND} AS stategraph-ui

ARG USERNAME

# Copy remaining source files (includes code/src/pricing_service/infracost, if it was in context)
COPY --chown=${USERNAME}:${USERNAME} ./code /tmp/mono/code/

FROM stategraph-ui AS stategraph-devcontainer
# dune generates merlin configuration as part of `dune build`; no
# separate setup step is needed.

FROM stategraph-devcontainer AS stategraph-production-or-development

ARG DUNE_CACHE_ID

# Production or development only: build stategraph
# Skipped in the devcontainer image so it builds more quickly.
#
# The cache mount lets BuildKit persist dune's _build/ across image builds.
# We copy from the cache *into* the build context before make, then copy
# the resulting _build/ *back to* the cache (and leave it in the image
# layer for runtime — _build/ is not bind-mounted at compose time, see
# docker-compose-dev.yml). Net effect: incremental dune builds across
# rebuilds on the same runner. First build is full (cache empty); typical
# PRs only recompile the changed modules.
#
# We deliberately do NOT restore from /dune-cache here. The upstream
# stategraph-pricing-development step already does the restore, and dune
# marks some of its outputs read-only (.dune/configurator, generated sources,
# ...) so a second `cp -aT` over them hits "Permission denied" trying to
# unlink-and-recreate.
#
# Caveat: when BuildKit reuses the upstream layer -- the common case, since
# OCaml-only edits invalidate this stage but leave stategraph-pricing-* and
# stategraph-ui-* cached -- the /tmp/mono/_build/ inherited here is that
# layer's frozen filesystem (pricing + hermes from when the layer was last
# built), not the freshest /dune-cache snapshot. dune still does incremental
# work against that state, and the save below writes the comprehensive tree
# back to the cache for subsequent full rebuilds.
#
# The /go-cache mount persists Go's module and build caches (GOMODCACHE/
# GOCACHE) for the in-build Go compilations — hcl_native_shim here. The
# pricing-service build is upstream (stategraph-pricing-development) and
# shares the same cache there.
#
# `sharing=locked` for the same reason as the upstream pricing step: the save
# below is not safe against a concurrent build's `rm -rf`.
RUN --mount=type=cache,id=${DUNE_CACHE_ID},target=/dune-cache,uid=1000,gid=1000,sharing=locked \
    --mount=type=cache,target=/go-cache,uid=1000,gid=1000 \
    eval $(opam env) && \
    export PATH="$PATH:$HOME/.local/bin" && \
    export GOMODCACHE=/go-cache/mod GOCACHE=/go-cache/build && \
    make -C code stategraph && \
    rm -rf /dune-cache/_build && \
    cp -aT /tmp/mono/_build /dune-cache/_build

# Both in production and development builds, we want the backend to be built.
# Keep the build-heavy layers in their own stages, then assemble stategraph-dev
# from a clean ocaml-deps base below. That keeps the final image from carrying
# successive full _build/ snapshots from the pricing, UI, and backend build
# layers; CI only needs the final _build/ tree at /tmp/mono/_build.

# Devcontainer mode deliberately stops before the product build. Preserve that
# behavior for people who build `stategraph-dev` with DEPLOYMENT_KIND=devcontainer.
FROM stategraph-devcontainer AS stategraph-devcontainer-final

ARG USERNAME
COPY --chown=${USERNAME}:${USERNAME} ./ /tmp/mono

# Start from a clean base and import only _build (see a few lines below):
# ignore in-tree artifacts, such as pricing and UI things.
FROM ocaml-deps AS stategraph-production-final

ARG USERNAME
# Copy the rest of the repo (all frontend/backend code has been brought in before)
COPY --chown=${USERNAME}:${USERNAME} ./ /tmp/mono
COPY --from=stategraph-production-or-development --chown=${USERNAME}:${USERNAME} /tmp/mono/_build /tmp/mono/_build

# Development ships the same built backend as production.
FROM stategraph-production-final AS stategraph-development-final

# Rejoin stages
ARG DEPLOYMENT_KIND
FROM stategraph-${DEPLOYMENT_KIND}-final AS stategraph-dev

ARG USERNAME
# FOCUS billing ETL, for Sgs_test_focus_sync.
COPY --from=focus-etl /usr/local/bin/duckdb /usr/local/bin/duckdb
COPY --from=focus-etl /usr/local/share/duckdb/extensions /usr/local/share/duckdb/extensions
COPY --from=focus-etl --chown=${USERNAME}:${USERNAME} /usr/local/bin/load-focus-billing /usr/local/bin/load-focus-billing

#########################################################################################################################
# We're done with the development and devcontainer images at this point. Below are things only for the production image #
#########################################################################################################################

# Orchestration engine binaries, one per edition, and the iris UI for the
# unified image. The image serves hermes on its default host and iris on the
# TERRAT_UI_BASE host, one console per brand. Deliberately narrower than the
# terrat-build stage further down: no ttm.
FROM ocaml-deps AS terrat-server-build

ARG USERNAME
ARG DUNE_CACHE_ID

COPY --chown=${USERNAME}:${USERNAME} ./ /tmp/mono

RUN --mount=type=cache,id=${DUNE_CACHE_ID},target=/dune-cache,uid=1000,gid=1000,sharing=locked \
    eval $(opam env) && \
    export PATH="$PATH:$HOME/.local/bin" && \
    if [ -d /dune-cache/_build ]; then \
      mkdir -p /tmp/mono/_build && \
      cp -aT /dune-cache/_build /tmp/mono/_build; \
    fi && \
    make -C code terrat_ee && \
    make -C code terrat_oss && \
    make -C code iris && \
    rm -rf /dune-cache/_build && \
    cp -aT /tmp/mono/_build /dune-cache/_build

# The OSS server binary. Built from public code only, so that the OSS image
# never reaches stategraph-dev and the private stages behind it (pricing,
# hermes). Chained on terrat-server-build for the reasons terrat-build gives
# below: the source is there, the dune cache restored, and the libraries both
# builds share compiled. The /go-cache mount is for hcl_native's Go shim, which
# the server links.
FROM terrat-server-build AS stategraph-server-oss-build

ARG DUNE_CACHE_ID

RUN --mount=type=cache,id=${DUNE_CACHE_ID},target=/dune-cache,uid=1000,gid=1000,sharing=locked \
    --mount=type=cache,target=/go-cache,uid=1000,gid=1000 \
    eval $(opam env) && \
    export PATH="$PATH:$HOME/.local/bin" && \
    export GOMODCACHE=/go-cache/mod GOCACHE=/go-cache/build && \
    dune build code/src/sgs_cli_oss/sgs_cli_oss.exe && \
    rm -rf /dune-cache/_build && \
    cp -aT /tmp/mono/_build /dune-cache/_build

# Build oauth2-proxy from stategraph fork (has HTTP session storage support)
FROM golang:1.27-alpine@sha256:4c9fe60190a2a3350ddc51de80d0224b8a6698d12bdfc999fee45ea9d6c46dbc AS oauth2-proxy-build
RUN apk add --no-cache git make
WORKDIR /src
# Pinned to a commit, not a branch: a branch tip makes the image content depend on
# when it was built rather than on this file.
ARG OAUTH2_PROXY_REF=f6dc14cce0a4d16791fec34a0638b9c77e034cd0
RUN git init -q . && \
    git remote add origin https://github.com/stategraph/oauth2-proxy.git && \
    git fetch --depth 1 origin "${OAUTH2_PROXY_REF}" && \
    git checkout -q FETCH_HEAD
# GOTOOLCHAIN=auto lets Go fetch a newer toolchain when go.mod asks for one this
# image does not carry.
RUN GOTOOLCHAIN=auto CGO_ENABLED=0 go build -ldflags="-s -w" -o /oauth2-proxy .

# Final server image, in two editions assembled from one base. The base is
# everything edition-blind: packages, the runit tree, nginx, oauth2-proxy and
# the orchestration console (iris). Each edition layer below adds its server,
# its terrat and the tools its features shell out to; the enterprise one also
# adds the Stategraph console (hermes) and the client.
FROM base-tenv-tofu AS stategraph-server-base

ARG USERNAME

# base-tenv-tofu upgraded its packages when its layers were built, and a builder
# with a persistent layer cache goes on reusing those layers for as long as
# nothing above them changes, so a release can ship packages that are weeks old.
# OS_REFRESH is a cache key and nothing else: release.yml sets it to the build
# date, which re-runs this upgrade whenever the date moves.
ARG OS_REFRESH
RUN apk upgrade --no-cache

RUN apk add --no-cache \
    gettext \
    gmp \
    jq \
    libffi \
    libretls \
    nginx \
    nginx-mod-http-js \
    postgresql-client \
    py3-cryptography \
    py3-jwt \
    py3-pip \
    py3-requests \
    py3-yaml \
    python3 \
    runit

COPY --from=oauth2-proxy-build /oauth2-proxy /usr/local/bin/oauth2-proxy
# The ${USERNAME} user/group (and TENV_ROOT) were created in base-tenv-tofu;
# reuse them as the service account rather than creating a separate user.
RUN mkdir -p /usr/local/bin /etc/service/stategraph /etc/service/nginx /etc/service/nginx/control /etc/service/pricing-service /etc/service/terrat /usr/local/share/stategraph/ui /usr/local/share/terrat/ui/assets /var/cache/stategraph/terraform-plugins /var/cache/stategraph/tofu-workdir /var/cache/stategraph/tofu-generated /var/cache/stategraph/gap-analysis
RUN chown -R ${USERNAME}:${USERNAME} /etc/service /usr/local/share/stategraph /usr/local/share/terrat /etc/nginx /var/lib/nginx /var/log/nginx /run /var/cache/stategraph
COPY --chown=${USERNAME}:${USERNAME} docker/stategraph/service/stategraph /etc/service/stategraph/run
COPY --chown=${USERNAME}:${USERNAME} docker/stategraph/service/nginx /etc/service/nginx/run
# Shutdown path. runit-init replaces runsvdir as the container's main process so
# a stop signal drains the services instead of orphaning them; nginx's control/t
# hook makes `sv down` send nginx a graceful SIGQUIT rather than a fast TERM.
COPY --chown=${USERNAME}:${USERNAME} --chmod=755 docker/stategraph/runit-init /usr/local/bin/runit-init
COPY --chown=${USERNAME}:${USERNAME} --chmod=755 docker/stategraph/service/nginx-control-t /etc/service/nginx/control/t
# The orchestration switch, in one place: the CMD below and service/nginx both
# run before any binary reads the configuration, so both ask this.
COPY --chown=${USERNAME}:${USERNAME} --chmod=755 docker/stategraph/orchestration-enabled /usr/local/bin/orchestration-enabled
COPY --chown=${USERNAME}:${USERNAME} docker/stategraph/service/pricing-service /etc/service/pricing-service/run
# terrat (orchestration engine) is gated by the image CMD, same mechanism as
# pricing-service. The CMD decides on each start, so a container restarted with
# a different setting follows it.
COPY --chown=${USERNAME}:${USERNAME} docker/stategraph/service/terrat /etc/service/terrat/run
# Catalog-generated column-level grants for the least-privilege FDW role; the
# terrat service applies them (convergently) after its migrations run.
COPY --chown=${USERNAME}:${USERNAME} code/src/sgs_terrateam_catalog/fdw_grants.sql /usr/local/share/stategraph/fdw_grants.sql
# pricing-service is opt-in. The image CMD (below) marks it `down` unless
# STATEGRAPH_PRICING_SERVICE_URL is set in the container environment, so runit
# never starts it when cost is off -- declarative, and it survives container
# recreation. See https://stategraph.com/docs/cost/setup.
COPY --chown=${USERNAME}:${USERNAME} docker/stategraph/nginx.conf.template /etc/nginx/nginx.conf.template
COPY --chown=${USERNAME}:${USERNAME} docker/stategraph/events.js /etc/nginx/events.js
# iris, served on the TERRAT_UI_BASE host. A dune directory target, like hermes
# in stategraph-server-ee, and the same path the standalone terrat images use,
# so the nginx template keeps one root for it.
COPY --from=terrat-server-build /tmp/mono/_build/default/code/src/iris/ui-export/ /usr/local/share/terrat/ui/assets/

# Set oauth2-proxy path
ENV STATEGRAPH_OAUTH2_PROXY_PATH=/usr/local/bin/oauth2-proxy
# terrat and sgs share one origin, and sgs names its console cookie "session".
# terrat reads this name for its own session cookie; sgs reads it to expire
# that cookie on logout. Set at image level so that both processes see it.
ENV TERRAT_SESSION_COOKIE_NAME=terrat_session

USER ${USERNAME}
EXPOSE 8080
# Cost estimation is opt-in: unless STATEGRAPH_COST_ENABLED is true, mark the
# pricing-service `down` so runit never starts it (no idle process). Set
# STATEGRAPH_COST_ENABLED=true in your deployment environment to enable cost
# durably; runit then starts the service, which loads + weekly-refreshes the
# price book.
# Orchestration uses the same mechanism, and asks orchestration-enabled for the
# rule so the shell side of it is written once.
CMD case "$STATEGRAPH_COST_ENABLED" in true|1) ;; *) touch /etc/service/pricing-service/down ;; esac; \
    if orchestration-enabled; then rm -f /etc/service/terrat/down; else touch /etc/service/terrat/down; fi; \
    exec /usr/local/bin/runit-init

# The OSS edition: orchestration through Stategraph. It ships no pricing
# service, so that runit service is marked down in the image itself; the CMD's
# touch is then a no-op whatever STATEGRAPH_COST_ENABLED says.
FROM stategraph-server-base AS stategraph-server-oss

ARG USERNAME

COPY --from=stategraph-server-oss-build /tmp/mono/_build/default/code/src/sgs_cli_oss/sgs_cli_oss.exe /usr/local/bin/stategraph-server
COPY --from=terrat-server-build --chown=${USERNAME}:${USERNAME} /tmp/mono/_build/default/code/src/terrat_oss/terrat_oss.exe /usr/local/bin/terrat
RUN touch /etc/service/pricing-service/down

# The enterprise edition: the whole of Stategraph, with the tools its cost,
# gap-analysis and import features shell out to.
FROM stategraph-server-base AS stategraph-server-ee

ARG USERNAME

USER root
# Python dependencies of the gap analysis tool
RUN pip3 install --no-cache-dir --break-system-packages boto3 google-cloud-asset>=3.24.0
# FOCUS billing ETL (see the focus-etl stage).
COPY --from=focus-etl /usr/local/bin/duckdb /usr/local/bin/duckdb
COPY --from=focus-etl /usr/local/share/duckdb/extensions /usr/local/share/duckdb/extensions
COPY --from=focus-etl --chown=${USERNAME}:${USERNAME} /usr/local/bin/load-focus-billing /usr/local/bin/load-focus-billing
# The client and the Stategraph console: enterprise only (OSS users run the
# same client, and the OSS edition ships no console for now).
COPY --from=stategraph-dev /tmp/mono/_build/default/code/src/sgc/sgc.exe /usr/local/bin/stategraph
# From _build, not the source tree: the Next.js export is now a dune directory
# target (code/src/hermes/dune), so it travels with _build and survives the
# /dune-cache restore. Taking it from the source tree relied on a stale out/
# left behind by a previous build, which does not exist on a clean checkout.
COPY --from=stategraph-dev /tmp/mono/_build/default/code/src/hermes/ui-export/ /usr/local/share/stategraph/ui/
COPY --from=stategraph-dev /tmp/mono/_build/default/code/src/sgs_cli/sgs_cli.exe /usr/local/bin/stategraph-server
COPY --from=terrat-server-build --chown=${USERNAME}:${USERNAME} /tmp/mono/_build/default/code/src/terrat_ee/terrat_ee.exe /usr/local/bin/terrat
COPY --from=stategraph-dev --chown=${USERNAME}:${USERNAME} --chmod=755 /tmp/mono/code/src/sg_gap_analysis/sg-gap-analysis /usr/local/bin/sg-gap-analysis
COPY --from=stategraph-dev --chown=${USERNAME}:${USERNAME} --chmod=755 /tmp/mono/code/src/sg_tofu_import/sg-tofu-import /usr/local/bin/sg-tofu-import
COPY --from=stategraph-dev --chown=${USERNAME}:${USERNAME} /tmp/mono/code/src/sg_tofu_import/mappings /usr/local/share/stategraph/mappings
# Pricing service for cost estimation. Opt-in via STATEGRAPH_PRICING_SERVICE_URL.
COPY --from=stategraph-dev --chown=${USERNAME}:${USERNAME} --chmod=755 /tmp/mono/_build/default/code/src/pricing_service/pricing-service /usr/local/bin/pricing-service
COPY --chown=${USERNAME}:${USERNAME} --chmod=755 code/src/pricing_service/load-pricing-data /usr/local/bin/load-pricing-data
USER ${USERNAME}

# The image every workflow, compose file and deployment names: the enterprise
# edition.
FROM stategraph-server-ee AS stategraph-server

# Final client image (minimal Alpine for small size)
FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS stategraph
# The minirootfs lags its own package branch, so upgrade what it pre-installed.
# OS_REFRESH keys the layer cache, as in stategraph-server-base.
ARG OS_REFRESH
RUN apk upgrade --no-cache
RUN apk add --no-cache libffi gmp libretls curl brotli-libs zstd-libs libpsl libidn2 nghttp2-libs c-ares
COPY --from=stategraph-dev /tmp/mono/_build/default/code/src/sgc/sgc.exe /usr/local/bin/stategraph
ENTRYPOINT ["/usr/local/bin/stategraph"]

#######################################
# Terrateam server binaries + images. #
#######################################

# These build on `ocaml-deps` (the shared opam sandbox) and are
# otherwise self-contained: terrat copies its own source and builds its own
# artifacts, with no dependency on the stategraph product build.
# This keeps terrat's inputs explicit (a clean slate it manages itself) and lets the
# terrat images build in any DEPLOYMENT_KIND without dragging in the
# private-infracost pricing stage. The stages are additive: they are only
# reached via `--target ttm|terrat-ee|terrat-oss`, and no existing
# stategraph-* stage or CI depends on them.
#
# Reuse of artifacts from stategraph builds (e.g. in-tree OCaml libraries shared between
# stategraph and terrateam: abb_*, pgsql_*, etc.) happens thanks to the /dune-cache mount
# (when it's warm, obviously), without depending on those
# stages. The cp -aT restore-into-fresh-tree / rm+save mirrors
# stategraph-pricing-development; sharing=locked serializes concurrent builds
# whose rm -rf/cp would otherwise race.
#
# Build all three terrat server binaries + the iris UI in a single invocation.
# `make -C code terrat` builds the @code/terrat alias (terrat_oss/terrat_ee/ttm
# exes + @code/src/iris/all) in one dune call -- dune holds a global workspace
# lock, so parallel make calls would only contend.
# Chained on terrat-server-build (which already copied the source, restored the
# dune cache, and compiled terrat_ee), so this only builds the remaining alias
# targets incrementally. No cache restore here: the parent already did it, and
# re-restoring would overlay whatever the shared mount holds NOW -- possibly a
# concurrent stategraph build's _build -- over a tree that is already correct.
# The save stays, so the cache ends with the fullest _build.
FROM terrat-server-build AS terrat-build

ARG DUNE_CACHE_ID

RUN --mount=type=cache,id=${DUNE_CACHE_ID},target=/dune-cache,uid=1000,gid=1000,sharing=locked \
    eval $(opam env) && \
    export PATH="$PATH:$HOME/.local/bin" && \
    make -C code terrat && \
    rm -rf /dune-cache/_build && \
    cp -aT /tmp/mono/_build /dune-cache/_build

# iris' static assets are a dune directory target (code/src/iris/dune ->
# ui-export), so they travel inside _build/ and survive the /dune-cache restore
# -- the ee/oss images copy the UI from _build/, same as stategraph-server does
# for hermes' ui-export. (This avoids the dist/-is-gitignored staleness trap: a
# restored _build no longer leaves the UI missing.)

# region:terrat-images
# Final ttm image
FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS ttm
# The minirootfs lags its own package branch, so upgrade what it pre-installed.
RUN apk upgrade --no-cache
COPY --from=terrat-build /tmp/mono/_build/default/code/src/ttm/ttm.exe /usr/local/bin/ttm
WORKDIR /mnt
ENTRYPOINT ["/usr/local/bin/ttm"]

# Shared runtime base for the terrat-ee / terrat-oss server images
FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS terrat-final-base
# The minirootfs lags its own package branch, so upgrade what it pre-installed.
RUN apk upgrade --no-cache
# These are the Terrateam-branded images, so a repository whose configuration
# names no brand gets Terrateam comments and check names. The unified
# stategraph image leaves this unset and gets the stategraph default.
ENV TERRAT_BRAND=terrateam
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    gettext \
    gmp \
    jq \
    libffi \
    libretls \
    nginx \
    py3-cryptography \
    py3-jwt \
    py3-requests \
    py3-yaml \
    python3 \
    runit \
    strace \
    sudo
RUN addgroup -S terrat && adduser -S -G terrat terrat
RUN mkdir -p /usr/local/bin /etc/service/terrat /etc/service/nginx /etc/service/nginx/control /usr/local/share/terrat/ui/assets
# CA-cert installer: root-owned, runnable (not writable) by terrat via a narrow
# sudoers rule; reads the CUSTOM_CA_CERT env var at container start.
COPY docker/terrat/install-ca-cert.py /usr/local/bin/install-ca-cert
RUN chmod 755 /usr/local/bin/install-ca-cert && \
    chown root:root /usr/local/bin/install-ca-cert
RUN echo 'terrat ALL=(root) NOPASSWD:SETENV: /usr/local/bin/install-ca-cert' > /etc/sudoers.d/terrat && \
    chmod 440 /etc/sudoers.d/terrat
RUN chown -R terrat:terrat /etc/service /usr/local/share/terrat /etc/nginx /var/lib/nginx /var/log/nginx /run
# runit services: `terrat` runs migrate then the server (listens on 8180);
# `nginx` renders nginx.conf.template (fronts on 8080) and serves the iris SPA.
COPY docker/terrat/service/terrat /etc/service/terrat/run
COPY docker/terrat/service/nginx /etc/service/nginx/run
# Shutdown path. runit-init replaces runsvdir as the container's main process so
# Fly's stop signal drains the services instead of orphaning them; nginx's
# control/t hook makes `sv down` send nginx a graceful SIGQUIT, not a fast TERM.
COPY --chmod=755 docker/terrat/runit-init /usr/local/bin/runit-init
COPY --chmod=755 docker/terrat/service/nginx-control-t /etc/service/nginx/control/t
COPY docker/terrat/nginx.conf.template /etc/nginx/nginx.conf.template
COPY --from=terrat-build /tmp/mono/_build/default/code/src/iris/ui-export/ /usr/local/share/terrat/ui/assets/
USER terrat
EXPOSE 8080
CMD ["/usr/local/bin/runit-init"]

# Final terrat-ee image
FROM terrat-final-base AS terrat-ee
COPY --from=terrat-build /tmp/mono/_build/default/code/src/terrat_ee/terrat_ee.exe /usr/local/bin/terrat

# Final terrat-oss image
FROM terrat-final-base AS terrat-oss
COPY --from=terrat-build /tmp/mono/_build/default/code/src/terrat_oss/terrat_oss.exe /usr/local/bin/terrat
# endregion:terrat-images
