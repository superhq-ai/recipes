# The npm distribution includes Codex's platform binaries and companion tools.
# Its optional platform packages are pinned to the same exact release.
set -eu
export DEBIAN_FRONTEND=noninteractive

CODEX_VERSION=0.165.0
cat > /etc/apt/sources.list.d/debian.sources << 'SOURCES'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: trixie-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
SOURCES
rm -f /etc/apt/sources.list
apt-get update -qq
apt-get upgrade -y -qq --no-install-recommends
apt-get install -y -qq --no-install-recommends ca-certificates curl git ripgrep nodejs npm
apt-get clean
rm -rf /var/lib/apt/lists/*

npm install --global --prefix /opt/codex --ignore-scripts --no-audit --no-fund "@openai/codex@${CODEX_VERSION}"
npm cache clean --force

cat > /usr/local/bin/codex << 'LAUNCHER'
#!/bin/sh
# Shuru's default HOME is /; keep login state at a documented mount point.
export CODEX_HOME="${CODEX_HOME:-/root/.codex}"
mkdir -p "$CODEX_HOME"
if [ -f /usr/local/share/ca-certificates/shuru-proxy.crt ]; then
    export CODEX_CA_CERTIFICATE="${CODEX_CA_CERTIFICATE:-/etc/ssl/certs/ca-certificates.crt}"
fi
exec /opt/codex/bin/codex "$@"
LAUNCHER
chmod 0755 /usr/local/bin/codex
codex --version
dpkg-query -W -f '${Package} ${Version}\n' git ripgrep nodejs npm
