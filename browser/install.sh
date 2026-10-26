# Step 1: Chromium from the Debian archive, run by an unprivileged user.
#
# Debian keeps only the newest build of a package in a suite, so chromium
# cannot be pinned by exact version the way docker-ce is: the pinned build
# would vanish from the archive at the next security update. The security
# archive is enabled instead, so a build gets the current fixes, and the
# versions installed are printed at the end for the build log.
set -eu
export DEBIAN_FRONTEND=noninteractive

echo "==> Upgrading Debian base (main, security and updates archives)"
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

# gtk3 wants a gsettings backend, dconf wants a session bus, and the default
# provider of that bus is dbus-user-session, which hard-depends on systemd.
# dbus-x11 provides the same bus without it, and the pin makes sure nothing
# drags systemd in behind our back: the build fails instead.
cat > /etc/apt/preferences.d/no-systemd << 'PIN'
Package: systemd systemd-sysv libpam-systemd dbus-user-session
Pin: release *
Pin-Priority: -1
PIN

echo "==> Installing chromium"
apt-get install -y -qq --no-install-recommends chromium chromium-sandbox fonts-liberation dbus-x11
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "==> Creating the browser user"
useradd --create-home --home-dir /home/browser --shell /usr/sbin/nologin browser

echo "==> Installed:"
dpkg-query -W -f '${Package} ${Version}\n' chromium chromium-sandbox fonts-liberation
