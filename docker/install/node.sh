#!/usr/bin/env bash
# fnm layout so the entrypoint can link it in and `fnm current` reports the version
set -euo pipefail
dir="/opt/node/v${NODE_VERSION}/installation"
mkdir -p "$dir"
curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
  | tar -xJ -C "$dir" --strip-components=1 --no-same-owner
ln -s "v${NODE_VERSION}/installation" /opt/node/current
# Node 25+ no longer bundles corepack
export PATH="/opt/node/current/bin:$PATH" NPM_CONFIG_CACHE=/tmp/npm-cache
npm install -g --no-fund --no-audit corepack
corepack enable
rm -rf /tmp/npm-cache /root/.npm
node --version
corepack --version
