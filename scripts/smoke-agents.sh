#!/bin/bash
# Build both agents, boot again offline, and exercise auth with synthetic keys.
# Does not read personal credentials or make model calls. Requires local Shuru.
set -euo pipefail
cd "$(dirname "$0")/.."

for name in claude-code codex; do
    echo "==> Build and reboot $name"
    shuru run --recipe "./$name" --memory 4096 \
        --mount "$PWD/$name:/recipe" -- sh /recipe/check.sh
done

# The real synthetic value is visible only to the host process/proxy. The
# guest must get a placeholder, and Codex must save only that placeholder.
export SHURU_SMOKE_KEY="shuru-recipe-test-${RANDOM}-${RANDOM}"

echo '==> Claude Code recognizes proxy-injected auth'
shuru run --from claude-code --memory 4096 --allow-net \
    --secret CLAUDE_CODE_OAUTH_TOKEN=SHURU_SMOKE_KEY@api.anthropic.com \
    -- sh -ec '
        case "$CLAUDE_CODE_OAUTH_TOKEN" in shuru_tok_*) ;; *) exit 1 ;; esac
        claude auth status > /tmp/auth-status.json
        rg -q "\"authMethod\":\s*\"oauth_token\"" /tmp/auth-status.json
        echo "Claude recognizes OAuth placeholder."
    '

echo '==> Codex stores only a proxy placeholder'
shuru run --from codex --memory 4096 --allow-net \
    --secret OPENAI_API_KEY=SHURU_SMOKE_KEY@api.openai.com \
    -- sh -ec '
        case "$OPENAI_API_KEY" in shuru_tok_*) ;; *) exit 1 ;; esac
        printenv OPENAI_API_KEY | codex login --with-api-key
        rg -q shuru_tok_ /root/.codex/auth.json
        echo "Codex saved only the placeholder."
    '

echo '==> Runtime authentication did not modify the checkpoints'
for name in claude-code codex; do
    shuru run --from "$name" --memory 4096 -- sh -ec '
        test ! -e /root/.claude/.credentials.json
        test ! -e /root/.codex/auth.json
        test ! -e /.claude/.credentials.json
        test ! -e /.codex/auth.json
    '
done
echo 'Agent smoke tests passed (no live model calls).'
