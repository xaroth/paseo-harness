#!/usr/bin/env bash
# tool.sh <tool>: install the pinned fast tool into /opt/tools. Version comes from its Dockerfile ARG.
set -euo pipefail
# shellcheck source=docker/lib/tools.sh
source "$(dirname "$0")/../lib/tools.sh"

tool="${1:?usage: tool.sh <tool>}"
tool_known "$tool" || { echo "unknown tool: $tool" >&2; exit 1; }
arg="$(tool_arg_var "$tool")"
ver="${!arg:?$arg not set}"
root="${TOOLS_ROOT:-$TOOLS_IMAGE_ROOT}"

# temp HOME and cache so nothing the install or --version writes is left behind
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export PATH="$root/bin:/opt/node/current/bin:$PATH" HOME="$tmp/home" \
  NPM_CONFIG_CACHE="$tmp/npm-cache" CLAUDE_CONFIG_DIR="$tmp/claude"
mkdir -p "$HOME"
tool_install_env

tool_npm_install "$root/$tool/$ver" "$tool" "$ver"
tool_activate "$root" "$tool" "$ver"
"${TOOL_BIN[$tool]}" --version

chown -R 1000:1000 "$root"
