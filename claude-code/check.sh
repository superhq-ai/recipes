# Runs after a fresh boot; no credentials or model requests.
set -eu
test "$(claude --version)" = '2.1.312 (Claude Code)'
claude --help > /dev/null
git --version
rg --version
test ! -e /root/.claude/.credentials.json
test ! -e /.claude/.credentials.json
echo 'Claude Code installed; no credentials saved in the checkpoint.'
