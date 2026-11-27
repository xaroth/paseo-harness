# syntax=docker/dockerfile:1
# Each install step is a script under docker/install/, bind-mounted so a change
# to one script only rebuilds that layer. Pins are bumped by CI.
# Pins sit next to their layer so a bump only rebuilds from that layer.
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

# changes weekly to refresh apt packages
ARG APT_EPOCH
RUN --mount=type=bind,source=docker/install/apt.sh,target=/tmp/i.sh \
    --mount=type=bind,source=docker/apt-packages.txt,target=/tmp/apt-packages.txt \
    echo "apt epoch: ${APT_EPOCH:-none}" && /tmp/i.sh
ARG GH_MIN_VERSION=2.81.0
RUN --mount=type=bind,source=docker/install/gh.sh,target=/tmp/i.sh /tmp/i.sh
ARG NODE_VERSION=26.13.1
RUN --mount=type=bind,source=docker/install/node.sh,target=/tmp/i.sh /tmp/i.sh
ARG CLOUDFLARED_VERSION=2026.11.2
RUN --mount=type=bind,source=docker/install/cloudflared.sh,target=/tmp/i.sh /tmp/i.sh
ARG GO_VERSION=1.27.4
RUN --mount=type=bind,source=docker/install/go.sh,target=/tmp/i.sh /tmp/i.sh
ARG RUST_VERSION=1.100.0
RUN --mount=type=bind,source=docker/install/rust.sh,target=/tmp/i.sh /tmp/i.sh
ARG UV_VERSION=0.13.10
RUN --mount=type=bind,source=docker/install/uv.sh,target=/tmp/i.sh /tmp/i.sh
ARG JJ_VERSION=0.47.1
RUN --mount=type=bind,source=docker/install/jj.sh,target=/tmp/i.sh /tmp/i.sh
ARG FLATC_VERSION=25.12.19
RUN --mount=type=bind,source=docker/install/flatc.sh,target=/tmp/i.sh /tmp/i.sh
ARG FNM_VERSION=1.39.0
RUN --mount=type=bind,source=docker/install/fnm.sh,target=/tmp/i.sh /tmp/i.sh
RUN --mount=type=bind,source=docker/install/user.sh,target=/tmp/i.sh /tmp/i.sh
ARG CHROME_DEVTOOLS_MCP_VERSION=1.14.0
RUN --mount=type=bind,source=docker/install/tool.sh,target=/tmp/install/tool.sh \
    --mount=type=bind,source=docker/lib/tools.sh,target=/tmp/lib/tools.sh \
    /tmp/install/tool.sh chrome-devtools-mcp
ARG PLAYWRIGHT_MCP_VERSION=0.0.86
RUN --mount=type=bind,source=docker/install/tool.sh,target=/tmp/install/tool.sh \
    --mount=type=bind,source=docker/lib/tools.sh,target=/tmp/lib/tools.sh \
    /tmp/install/tool.sh playwright-mcp
ARG PASEO_VERSION=0.17.5
RUN --mount=type=bind,source=docker/install/tool.sh,target=/tmp/install/tool.sh \
    --mount=type=bind,source=docker/lib/tools.sh,target=/tmp/lib/tools.sh \
    /tmp/install/tool.sh paseo
ARG CLAUDE_CODE_VERSION=2.1.332
RUN --mount=type=bind,source=docker/install/tool.sh,target=/tmp/install/tool.sh \
    --mount=type=bind,source=docker/lib/tools.sh,target=/tmp/lib/tools.sh \
    /tmp/install/tool.sh claude

COPY docker/lib/ /usr/local/lib/
COPY --chmod=0755 docker/bin/ /usr/local/bin/
COPY --chmod=0755 docker/entrypoint.sh /usr/local/bin/entrypoint.sh
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
    HISTFILE=/config/shell/bash_history \
    PASEO_HOME=/config/paseo

# caches, all on the /cache volume
ENV GOPATH=/cache/go \
    GOMODCACHE=/cache/go/pkg/mod \
    GOCACHE=/cache/go/build \
    CARGO_HOME=/cache/cargo \
    UV_CACHE_DIR=/cache/uv \
    UV_PYTHON_INSTALL_DIR=/cache/uv/python \
    NPM_CONFIG_CACHE=/cache/npm \
    NPM_CONFIG_PREFIX=/cache/npm-global \
    FNM_DIR=/cache/fnm \
    PASEO_LOCAL_MODELS_DIR=/cache/paseo-models

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
    PASEO_LISTEN=0.0.0.0:6767 \
    PASEO_RELAY_ENABLED=false \
    PASEO_WEB_UI_ENABLED=true \
    PASEO_TRUSTED_PROXIES=loopback,uniquelocal \
    PATH=/cache/tools/bin:/opt/tools/bin:/cache/npm-global/bin:/opt/node/current/bin:/usr/local/go/bin:/opt/cargo/bin:/cache/go/bin:$PATH

VOLUME ["/config", "/cache"]
EXPOSE 6767

# start period covers the budgeted start-time update (UPDATE_START_BUDGET)
HEALTHCHECK --interval=30s --timeout=5s --start-period=300s --retries=3 \
  CMD curl -fsS -o /dev/null http://127.0.0.1:6767/api/health || exit 1

# -g: signal the whole process group so agent children stop with the daemon
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["serve"]
