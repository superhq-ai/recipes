# Step 1: Docker Engine from the official apt repository, pinned.
#
# Everything is pinned: the apt packages by exact version and the signing
# key by SHA-256. The build VM only reaches the hosts listed in recipe.json.
set -eu
export DEBIAN_FRONTEND=noninteractive

DOCKER_VERSION="5:29.9.2-1~debian.13~trixie"
CONTAINERD_VERSION="2.4.2-3~debian.13~trixie"
# Docker Release (CE deb), fingerprint 9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88
DOCKER_GPG_SHA256="1500c1f56fa9e26b9b8f42452a553675796ade0807cdce11975eb98170b3a570"

echo "==> Upgrading Debian base (main, security and updates archives)"
cat > /etc/apt/sources.list.d/debian.sources << 'EOF'
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
EOF
rm -f /etc/apt/sources.list
apt-get update -qq
apt-get upgrade -y -qq --no-install-recommends

echo "==> Adding Docker apt repository (key pinned by SHA-256)"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
echo "${DOCKER_GPG_SHA256}  /etc/apt/keyrings/docker.asc" | sha256sum -c -
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian trixie stable" \
    > /etc/apt/sources.list.d/docker.list
apt-get update -qq

echo "==> Installing docker-ce ${DOCKER_VERSION}, containerd.io ${CONTAINERD_VERSION}"
apt-get install -y -qq --no-install-recommends \
    "docker-ce=${DOCKER_VERSION}" "docker-ce-cli=${DOCKER_VERSION}" "containerd.io=${CONTAINERD_VERSION}"
apt-mark hold docker-ce docker-ce-cli containerd.io > /dev/null
apt-get clean
rm -rf /var/lib/apt/lists/*

# Inner isolation stays at Docker defaults plus no-new-privileges. The
# dockerd service itself is declared in recipe.json.
mkdir -p /etc/docker
printf '{\n  "no-new-privileges": true\n}\n' > /etc/docker/daemon.json

echo "==> Installed versions"
docker --version
containerd --version
runc --version | head -n 1
