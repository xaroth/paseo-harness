# syntax=docker/dockerfile:1
# Each install step is a script under docker/install/, bind-mounted so a change
# to one script only rebuilds that layer. Pins below are bumped by CI.
FROM debian:trixie-slim

ARG NODE_VERSION=24.22.3
ARG GO_VERSION=1.27.4
ARG RUST_VERSION=1.100.0
ARG CLOUDFLARED_VERSION=2026.11.2
ARG JJ_VERSION=0.47.1
ARG FLATC_VERSION=25.12.19
ARG FNM_VERSION=1.39.0
ARG UV_VERSION=0.13.10
ARG GH_MIN_VERSION=2.81.0
# set to a date to bust the apt layer cache on scheduled rebuilds
ARG APT_EPOCH

ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=bind,source=docker/install/apt.sh,target=/tmp/i.sh \
    --mount=type=bind,source=docker/apt-packages.txt,target=/tmp/apt-packages.txt \
    echo "apt epoch: ${APT_EPOCH:-none}" && /tmp/i.sh
RUN --mount=type=bind,source=docker/install/gh.sh,target=/tmp/i.sh /tmp/i.sh
RUN --mount=type=bind,source=docker/install/node.sh,target=/tmp/i.sh /tmp/i.sh
RUN --mount=type=bind,source=docker/install/cloudflared.sh,target=/tmp/i.sh /tmp/i.sh
RUN --mount=type=bind,source=docker/install/go.sh,target=/tmp/i.sh /tmp/i.sh
RUN --mount=type=bind,source=docker/install/rust.sh,target=/tmp/i.sh /tmp/i.sh
RUN --mount=type=bind,source=docker/install/uv.sh,target=/tmp/i.sh /tmp/i.sh
RUN --mount=type=bind,source=docker/install/jj.sh,target=/tmp/i.sh /tmp/i.sh
RUN --mount=type=bind,source=docker/install/flatc.sh,target=/tmp/i.sh /tmp/i.sh
RUN --mount=type=bind,source=docker/install/fnm.sh,target=/tmp/i.sh /tmp/i.sh
RUN --mount=type=bind,source=docker/install/user.sh,target=/tmp/i.sh /tmp/i.sh

COPY --chown=code:code docker/bashrc /home/code/.bashrc
COPY --chown=code:code docker/bash_profile /home/code/.bash_profile
# /etc/profile resets PATH in login shells (ssh, bash -l)
COPY docker/profile.sh /etc/profile.d/harness.sh
COPY docker/sshd_config /etc/ssh/sshd_harness.conf

# config, all on the /config volume
ENV CLAUDE_CONFIG_DIR=/config/claude \
    GH_CONFIG_DIR=/config/gh \
    GIT_CONFIG_GLOBAL=/config/git/config \
    JJ_CONFIG=/config/jj/config.toml \
    HISTFILE=/config/shell/bash_history

# caches, all on the /cache volume
ENV GOPATH=/cache/go \
    GOMODCACHE=/cache/go/pkg/mod \
    GOCACHE=/cache/go/build \
    CARGO_HOME=/cache/cargo \
    UV_CACHE_DIR=/cache/uv \
    UV_PYTHON_INSTALL_DIR=/cache/uv/python \
    NPM_CONFIG_CACHE=/cache/npm \
    NPM_CONFIG_PREFIX=/cache/npm-global \
    FNM_DIR=/cache/fnm

# tool settings
ENV NODE_VERSION=${NODE_VERSION} \
    WORKSPACE=/workspace \
    SHELL=/bin/bash \
    RUSTUP_HOME=/opt/rustup \
    CHROME_PATH=/usr/bin/chromium \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    DISABLE_TELEMETRY=1 \
    DISABLE_ERROR_REPORTING=1 \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    DISABLE_AUTOUPDATER=1 \
    DO_NOT_TRACK=1 \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    PATH=/cache/tools/bin:/opt/tools/bin:/cache/npm-global/bin:/opt/node/current/bin:/usr/local/go/bin:/opt/cargo/bin:/cache/go/bin:$PATH

VOLUME ["/config", "/cache"]

CMD ["bash"]
