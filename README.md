# paseo-harness

A Debian container image (`ghcr.io/xaroth/paseo-harness`) that runs the [Paseo](https://www.npmjs.com/package/@getpaseo/cli) daemon alongside a full development toolchain (Node, Go, Rust, Python via uv, gh, jj, cloudflared, Chromium) for coding agents such as Claude Code. Configuration, caches and the workspace live on volumes so the image can be replaced freely.
