# Runs after a fresh boot; no credentials or model requests.
set -eu
test "$(codex --version)" = 'codex-cli 0.165.0'
codex exec --help > /dev/null
git --version
rg --version
node --version
test ! -e /root/.codex/auth.json
test ! -e /.codex/auth.json
echo 'Codex installed; no credentials saved in the checkpoint.'
