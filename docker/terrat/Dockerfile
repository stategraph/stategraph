# GENERATED: the cog-managed sections below are pulled from
# docker/stategraph/Dockerfile (the source of truth) by docker/terrat/render.sh.
# Do not hand-edit the generated content between the cog / end markers. After
# changing a shared `# region:NAME` block in docker/stategraph/Dockerfile, run
# `docker/terrat/render.sh`; `docker/terrat/render.sh --check` gates staleness in CI.

# emit(NAME) copies the lines between `# region:NAME` and `# endregion:NAME` in
# docker/stategraph/Dockerfile into the generated blocks below.
# [[[cog
# import pathlib
# _src = pathlib.Path(cog.inFile).resolve().parent.parent / "stategraph" / "Dockerfile"
# _lines = _src.read_text().splitlines()
# def emit(region):
#     def find(kind):
#         marker = f"# {kind}:{region}"
#         for i, line in enumerate(_lines):
#             s = line.strip()
#             if s == marker or s.startswith(marker + " "):
#                 return i
#         raise SystemExit(f"cog: {kind}:{region} not found in {_src}")
#     for line in _lines[find("region") + 1 : find("endregion")]:
#         cog.outl(line)
# ]]]
# [[[end]]]

# Define an argument for the base image
ARG BASE_IMAGE

# Optional base setup stage if BASE_IMAGE is not provided
FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS build-base

# [[[cog emit("apk-base") ]]]
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
# [[[end]]]

# WORKDIR /tmp so the shared `mono/...`-relative opam paths resolve against /tmp/mono.
WORKDIR /tmp
RUN opam init -ay --disable-sandboxing --bare
COPY ./ /tmp/mono
# [[[cog emit("opam-switch") ]]]
RUN eval $(opam env) && \
    opam switch create -y 5.3.0 && \
    eval $(opam env) && \
    opam repository add opam-acsl mono/opam && \
    opam pin add -n ISO8601 mono/vendor/ISO8601 --no-depexts && \
    opam pin add -n cohttp mono/vendor/cohttp --no-depexts
# [[[end]]]
# [[[cog emit("opam-install") ]]]
RUN eval $(opam env) && cd mono/code && \
    opam install -j$(nproc --all) -y --no-depexts dune menhir && \
    cat opam.pins stategraph.pins | xargs opam install -j$(nproc --all) -y --no-depexts
# [[[end]]]
# [[[cog emit("ocamlformat") ]]]
RUN eval $(opam env) && opam pin add -y ocamlformat 0.29.0
# [[[end]]]
# OTH_EXCLUDE_TAGS: the hcl_ast `tofu_fmt_parity` group checks our HCL parser
# against `tofu fmt` as its ground truth. This image deliberately does
# not ship OpenTofu, so skip that group by tag.
RUN eval $(opam env) && cd /tmp/mono && \
    OTH_EXCLUDE_TAGS=HCL_AST_TESTS_NEEDING_TOFU make -C code test-terrat terrat && \
    mv _build /build-cache

# Use provided BASE_IMAGE if specified, otherwise use the build-base stage
FROM ${BASE_IMAGE:-build-base} AS build-setup

# Refresh source files on top of the (possibly prebuilt) base image.  The tree
# is wiped first: overlaying sources on the base's tree and reusing its _build
# produced hybrid binaries mixing object files from different tree states
# (#1733).  The base still pays for what it is good for -- the opam switch and
# system deps -- but every release compiles from exactly the checkout.
RUN rm -rf /tmp/mono
COPY ./ /tmp/mono

# Single clean `make -C code terrat` invocation, the same invocation
# docker/stategraph/Dockerfile uses.  GIT_SHA, when given, is stamped into the
# binary via Terrat_build_info so a shipped image can be verified against the
# source it claims to be built from.
FROM build-setup AS terrat-build
ARG GIT_SHA=""
WORKDIR /tmp/mono
RUN if [ -n "$GIT_SHA" ]; then \
      printf 'let sha = "%s"\n' "$GIT_SHA" > code/src/terrat_build_info/terrat_build_info.ml; \
    fi && \
    eval $(opam env) && \
    make -C code terrat

# [[[cog emit("terrat-images") ]]]
# Final code-indexer image
FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS code-indexer
RUN addgroup -S terrat && adduser -S -G terrat terrat
COPY --from=terrat-build /tmp/mono/_build/default/code/src/terrat_code_indexer/terrat_code_indexer.exe /usr/local/bin/terrat_code_indexer
USER terrat
WORKDIR /mnt
ENTRYPOINT ["/usr/local/bin/terrat_code_indexer"]

# Final ttm image
FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS ttm
COPY --from=terrat-build /tmp/mono/_build/default/code/src/ttm/ttm.exe /usr/local/bin/ttm
WORKDIR /mnt
ENTRYPOINT ["/usr/local/bin/ttm"]

# Shared runtime base for the terrat-ee / terrat-oss server images
FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS terrat-final-base
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
    sudo \
    yj
RUN addgroup -S terrat && adduser -S -G terrat terrat
RUN mkdir -p /usr/local/bin /etc/service/terrat /etc/service/nginx /usr/local/share/terrat/ui/assets
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
COPY docker/terrat/nginx.conf.template /etc/nginx/nginx.conf.template
COPY --from=terrat-build /tmp/mono/_build/default/code/src/iris/ui-export/ /usr/local/share/terrat/ui/assets/
USER terrat
EXPOSE 8080
CMD ["runsvdir", "/etc/service"]

# Final terrat-ee image
FROM terrat-final-base AS terrat-ee
COPY --from=terrat-build /tmp/mono/_build/default/code/src/terrat_ee/terrat_ee.exe /usr/local/bin/terrat

# Final terrat-oss image
FROM terrat-final-base AS terrat-oss
COPY --from=terrat-build /tmp/mono/_build/default/code/src/terrat_oss/terrat_oss.exe /usr/local/bin/terrat
# [[[end]]]
