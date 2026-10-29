# Native Claude Code, pinned to a release and its published SHA-256.
# Credentials are supplied only at runtime, never during recipe builds.
set -eu
export DEBIAN_FRONTEND=noninteractive

CLAUDE_VERSION=2.1.312
case "$(uname -m)" in
    aarch64)
        platform=linux-arm64
        checksum=dc4af28917455e009d26704b82a438353a06149e825b6cdf782908b2d28661f5
        ;;
    x86_64)
        platform=linux-x64
        checksum=4f4178ce41d83e23341ebfbaecdbcf8ea6bf7baea0690025abe49eeec3a5d01d
        ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

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
apt-get install -y -qq --no-install-recommends ca-certificates curl git ripgrep
apt-get clean
rm -rf /var/lib/apt/lists/*

curl -fsSL --retry 3 \
    "https://downloads.claude.ai/claude-code-releases/${CLAUDE_VERSION}/${platform}/claude" \
    -o /tmp/claude
printf '%s  %s\n' "$checksum" /tmp/claude | sha256sum -c -
install -D -m 0755 /tmp/claude /opt/claude-code/claude
rm /tmp/claude

# Keep the checkpoint's pinned version. Preserve caller overrides.
cat > /usr/local/bin/claude << 'LAUNCHER'
#!/bin/sh
export DISABLE_AUTOUPDATER="${DISABLE_AUTOUPDATER:-1}"
export CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-/root/.claude}"
# Bun/Node need the proxy CA explicitly in addition to their bundled roots.
if [ -f /usr/local/share/ca-certificates/shuru-proxy.crt ]; then
    export NODE_EXTRA_CA_CERTS="${NODE_EXTRA_CA_CERTS:-/usr/local/share/ca-certificates/shuru-proxy.crt}"
fi
exec /opt/claude-code/claude "$@"
LAUNCHER
chmod 0755 /usr/local/bin/claude

claude --version
dpkg-query -W -f '${Package} ${Version}\n' git ripgrep
