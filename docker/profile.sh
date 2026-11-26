# shellcheck shell=sh
# Keep image toolchains on PATH after /etc/profile resets it.
# Each entry is prepended, so the last one listed ends up first.
for d in /cache/go/bin /opt/cargo/bin /usr/local/go/bin /opt/node/current/bin /cache/npm-global/bin \
  /opt/tools/bin /cache/tools/bin; do
  case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
done
export PATH
