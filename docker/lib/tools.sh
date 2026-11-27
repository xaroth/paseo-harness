# shellcheck shell=bash disable=SC2034
# Fast tool table and per-tool layout, shared by install/tool.sh, update, doctor and harness-run.
# Layout under a root (/opt/tools in the image, /cache/tools for the overlay):
#   <root>/<tool>/<ver>/{bin,lib/node_modules}   npm global layout via -g --prefix
#   <root>/<tool>/current -> <ver>
#   <root>/bin/<bin> -> ../<tool>/current/bin/<bin>

TOOLS_IMAGE_ROOT=/opt/tools
TOOLS_OVERLAY_ROOT=/cache/tools

# image install order: most frequently bumped last
TOOLS=(chrome-devtools-mcp playwright-mcp paseo claude)

declare -A TOOL_PKG=(
  [paseo]=@getpaseo/cli
  [claude]=@anthropic-ai/claude-code
  [playwright-mcp]=@playwright/mcp
  [chrome-devtools-mcp]=chrome-devtools-mcp
)
declare -A TOOL_BIN=(
  [paseo]=paseo
  [claude]=claude
  [playwright-mcp]=playwright-mcp
  [chrome-devtools-mcp]=chrome-devtools-mcp
)
declare -A TOOL_ARG=(
  [paseo]=PASEO_VERSION
  [claude]=CLAUDE_CODE_VERSION
  [playwright-mcp]=PLAYWRIGHT_MCP_VERSION
  [chrome-devtools-mcp]=CHROME_DEVTOOLS_MCP_VERSION
)

tool_known() { [[ -n "${TOOL_PKG[$1]:-}" ]]; }

# paseo -> PIN_PASEO, chrome-devtools-mcp -> PIN_CHROME_DEVTOOLS_MCP
tool_pin_var() { local v="${1^^}"; echo "PIN_${v//-/_}"; }
tool_arg_var() { echo "${TOOL_ARG[$1]}"; }

# install env: skip browser downloads, keep claude from writing real config or self-updating
tool_install_env() {
  export PUPPETEER_SKIP_DOWNLOAD=1 PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 DISABLE_AUTOUPDATER=1 \
    NPM_CONFIG_UPDATE_NOTIFIER=false
}

# per-tool dead weight, globs relative to the install dir
tool_strip_paths() {
  case "$1" in
    # paseo always runs the claude on PATH, never the agent SDK's bundled native binary
    paseo) echo 'lib/node_modules/@getpaseo/cli/node_modules/@anthropic-ai/claude-agent-sdk-*' ;;
  esac
}

# tool_npm_install <dir> <tool> <ver> [npm args...]; scripts on: claude's postinstall installs its native binary
tool_npm_install() {
  local dir="$1" tool="$2" ver="$3" p
  shift 3
  npm install -g --prefix "$dir" --no-fund --no-audit --dangerously-allow-all-scripts "$@" "${TOOL_PKG[$tool]}@${ver}"
  while read -r p; do
    # shellcheck disable=SC2086 # glob on purpose
    [[ -n "$p" ]] && rm -rf "${dir:?}"/$p
  done < <(tool_strip_paths "$tool")
  # source maps and other platforms' prebuilds are dead weight
  find "$dir" -name '*.map' -type f -delete
  find "$dir" -type d -path '*/prebuilds/*' ! -path '*/prebuilds/linux-x64*' -prune -exec rm -rf {} +
}

# ln -s + mv -T replaces a link atomically
tool_relink() {
  local target="$1" link="$2"
  ln -sfn "$target" "$link.new"
  mv -T "$link.new" "$link"
}

# tool_activate <root> <tool> <ver>: point current and the bin link at <ver>
tool_activate() {
  local root="$1" tool="$2" ver="$3" bin="${TOOL_BIN[$2]}"
  mkdir -p "$root/bin"
  tool_relink "$ver" "$root/$tool/current"
  tool_relink "../$tool/current/bin/$bin" "$root/bin/$bin"
}
