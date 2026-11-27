# paseo-harness

A Debian container image (`ghcr.io/xaroth/paseo-harness`) that runs the [Paseo](https://www.npmjs.com/package/@getpaseo/cli) daemon alongside a development toolchain (Node, Go, Rust, Python via uv, gh, jj, cloudflared, Chromium) for coding agents such as Claude Code. Configuration, caches and the workspace live on volumes, so the image can be replaced freely. Paseo, Claude Code, Playwright MCP and Chrome DevTools MCP update at runtime without a new image.

## Quickstart

1. Copy the example settings:
   ```sh
   cp .env.example .env
   ```
2. In `.env`, set `PUBLIC_URL` to the https URL your reverse proxy serves (see [Reverse proxy](#reverse-proxy)) and `PASEO_PASSWORD` to the daemon password.
3. Start the container:
   ```sh
   docker compose up -d
   ```
4. Log in to Claude Code once; the login is stored on the config volume:
   ```sh
   docker compose exec -u code paseo-harness claude
   ```
5. Connect the Paseo app:
   ```sh
   docker compose exec paseo-harness pair
   ```
   `pair` prints `PUBLIC_URL`, the host, port and SSL setting to enter under Settings, Add host, Direct connection (or the equivalent `tcp://host:port?ssl=true` Connection URI under Advanced), and a QR code of `PUBLIC_URL` that opens the web UI. The password is `PASEO_PASSWORD`.

The entrypoint registers the `playwright` and `chrome-devtools` MCP servers with Claude Code at each start, both driving the image's headless Chromium. `register-mcp --remove` unregisters them.

## Reverse proxy

The daemon port is bound to `127.0.0.1:${PORT:-6767}` on the host. Put a TLS reverse proxy in front and set `PUBLIC_URL` to its URL. The host of `PUBLIC_URL` is added to the daemon's allowed hostnames.

Caddy (Caddyfile):

```caddyfile
paseo.example.com {
    reverse_proxy 127.0.0.1:6767
}
```

nginx, which needs the WebSocket upgrade headers:

```nginx
server {
    listen 443 ssl;
    server_name paseo.example.com;
    # ssl_certificate ...

    location / {
        proxy_pass http://127.0.0.1:6767;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 1d;
    }
}
```

`TRUSTED_PROXIES` sets which proxies' `X-Forwarded-*` headers the daemon trusts, in Express trust proxy syntax. Empty keeps `loopback,uniquelocal`, which covers a proxy on the host reaching the container through the Docker bridge.

### Dev server previews (optional)

Paseo can serve dev servers started by agents at a single-label name under the host of `SERVICE_BASE_URL`, such as `<script>--<project>.dev.example.com`. Set `SERVICE_BASE_URL`, for example `https://dev.example.com`, and route a wildcard to the same daemon port. These previews have no authentication, so keep the wildcard LAN-only. It also needs a wildcard certificate (DNS challenge). Add a block next to the main site in the Caddyfile:

```caddyfile
*.dev.example.com {
    tls {
        dns <provider> ...
    }
    @lan remote_ip private_ranges
    handle @lan {
        reverse_proxy 127.0.0.1:6767
    }
    respond 403
}
```

With nginx, use `server_name *.dev.example.com;`, the same `location` block as above, and `allow 192.168.0.0/16; deny all;` (adjust to your LAN).

Leave `SERVICE_BASE_URL` empty to disable previews.

## Volumes

| Mount | Default | Holds |
| --- | --- | --- |
| `/config` | named volume `config` | Claude, Paseo, gh, git, jj config, shell history, ssh keys |
| `/cache` | named volume `cache` | Go, Cargo, uv, npm, fnm caches, updated tools, Paseo local models |
| `$WORKSPACE` | bind mount of `WORKSPACE_HOST` (`./workspace`) | your repos |

Without the `cache` line in `compose.yaml`, `/cache` is an anonymous volume: it survives `docker compose up` recreates and is lost on `docker compose down` followed by `up`, or `up -V`. With `UPDATE_CHANNEL=latest`, the start-time update then reinstalls newer tool versions.

Paseo stores absolute paths. If you work on the same repos from the host, set `WORKSPACE` to the host path so both sides see the same path:

```sh
WORKSPACE_HOST=/home/me/src
WORKSPACE=/home/me/src
```

Worktrees go to `$WORKSPACE/.worktrees`; the entrypoint sets Paseo's `worktrees.root` there at each start.

`PUID` and `PGID` set the uid and gid of the container user `code`; match your host user (`id -u`, `id -g`) so files in the workspace keep your ownership.

## Updates

Paseo, Claude Code, Playwright MCP and Chrome DevTools MCP are installed in the image under `/opt/tools`. Newer versions install into `/cache/tools`, which comes first on `PATH`. The image versions stay as the fallback.

`update` runs at start (capped by `UPDATE_START_BUDGET`) and then every `UPDATE_INTERVAL`. Each version is installed in a staging directory and verified before it goes live (`--version`; for Paseo, a throwaway daemon must answer `/api/health`). A failed resolve, install or verification keeps the active version and is recorded as the tool's last error. A new Paseo goes live once no agent is running: `update` checks every 60 seconds, then restarts the daemon.

| Variable | Default | Meaning |
| --- | --- | --- |
| `UPDATE_CHANNEL` | `latest` | `latest`: newest release older than `UPDATE_MIN_AGE`. `image`: image versions only. `pinned`: `PIN_*` versions, image versions for tools without a pin |
| `UPDATE_TOOLS` | `paseo,claude,playwright-mcp,chrome-devtools-mcp` | tools kept up to date |
| `UPDATE_MIN_AGE` | `24h` | minimum release age; accepts `s`, `m`, `h`, `d` suffixes |
| `UPDATE_INTERVAL` | `6h` | how often to check while running; `0` checks at start only |
| `UPDATE_TIMEOUT` | `120` | seconds per install |
| `UPDATE_START_BUDGET` | `180` | total seconds the start-time update may take before the daemon boots |
| `PIN_PASEO`, `PIN_CLAUDE`, `PIN_PLAYWRIGHT_MCP`, `PIN_CHROME_DEVTOOLS_MCP` | empty | exact version or npm tag for that tool; empty follows `UPDATE_CHANNEL` |

An exact pin skips the minimum age and may be older than the image version. Otherwise a resolved version that is not newer than the image version uses the image.

Commands, run with `docker compose exec paseo-harness <command>`:

| Command | Effect |
| --- | --- |
| `update --check` | per tool: image, overlay, previous and target version, last error |
| `update` | update now; waits if another update is running |
| `update --rollback <tool>` | switch back to the previous version, or to the image version when there is none. The version rolled back from is skipped until another version resolves or a pin names it |
| `doctor` | toolchain versions, fast tool versions in use (image or overlay) and last update errors, mounts, Claude and gh auth, registered MCP servers, daemon health, relay and `worktrees.root` |

If the overlay Paseo crashes 5 times within 300 seconds, the supervisor falls back to the image Paseo. To pin the whole image, set `IMAGE`, for example `ghcr.io/xaroth/paseo-harness:v0.1.0`, and `UPDATE_CHANNEL=image`.

## Security

- The daemon port is published on `127.0.0.1` only, the SSH port too unless `SSH_BIND` says otherwise. Reach the daemon through a reverse proxy.
- The container does not start without a password. Set `PASEO_PASSWORD` in `.env`. Compose interpolates `$` in `.env` values, so single-quote a password that contains `$`: `PASEO_PASSWORD='pa$$word'`. The password is passed to shells and helpers through `/run/harness/env` (mode 0600), not the config volume.
- `ALLOW_NO_PASSWORD=1` boots without a password; any client that can reach the daemon is accepted. Use it only on a network you fully trust.
- The container user `code` has no sudo. System packages belong in the image.
- Dev server previews (`SERVICE_BASE_URL`) have no authentication. Expose the wildcard on your LAN only.
- The Paseo relay is off (`PASEO_RELAY_ENABLED=false`); clients connect directly through your proxy. Claude Code telemetry, error reporting and auto-updates are disabled.

## SSH (optional)

`SSHD=1` starts sshd inside the container for VS Code Remote SSH and similar tools. Key auth only, user `code`. It listens on `${SSH_BIND:-127.0.0.1}:${SSH_PORT:-2222}`. Public keys go in `ssh/authorized_keys` on the config volume. `SSH_KEYS_FROM_GITHUB=<user>` fetches `https://github.com/<user>.keys` into `ssh/authorized_keys.github` at each start, keeping the last copy when GitHub is unreachable. The host key lives on the config volume, so it survives recreates.

```sh
ssh -p 2222 code@127.0.0.1
```

## Keyring (optional)

`KEYRING=1` starts a D-Bus session bus and an unlocked gnome-keyring (Secret Service) for tools that need an OS keyring. It is a throwaway keyring with a fixed password inside the container; do not store real credentials in it.
