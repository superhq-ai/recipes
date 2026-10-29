# Claude Code

Claude Code **2.1.312**, installed from Anthropic's native Linux binary with
SHA-256 verification, plus Git and ripgrep. Supports ARM64 and x86-64.
Background auto-updates are disabled so the installed version stays pinned.

From this repository, build and check it without credentials:

```sh
shuru run --recipe ./claude-code --memory 4096 -- claude --version
```

The examples below use the local recipe. Use `--recipe claude-code` to
resolve it through the official catalog. Build networking is separate from
runtime networking; model requests require `--allow-net`.

## Claude subscription

On the host, run `claude setup-token` and save its output in your secret
manager or host environment as `CLAUDE_CODE_OAUTH_TOKEN`. Then:

```sh
shuru run --recipe ./claude-code --memory 4096 --allow-net \
  --secret CLAUDE_CODE_OAUTH_TOKEN=CLAUDE_CODE_OAUTH_TOKEN@api.anthropic.com \
  -- claude -p 'Reply with exactly SHURU_OK' --model haiku
```

The guest receives a placeholder. Shuru substitutes the real token only in
HTTPS request headers to `api.anthropic.com`. The launcher trusts Shuru's
proxy CA without disabling certificate verification. Renew the host token
when it expires. An ordinary short-lived token taken from an existing
Claude login does not refresh automatically through this environment variable.

## Anthropic API key

Set `ANTHROPIC_API_KEY` in the host environment, then:

```sh
shuru run --recipe ./claude-code --memory 4096 --allow-net \
  --secret ANTHROPIC_API_KEY=ANTHROPIC_API_KEY@api.anthropic.com \
  -- claude -p 'Reply with exactly SHURU_OK' --model haiku
```

Choose one auth method per run. API keys use API billing; subscription
tokens use your Claude plan. Interactive API-key use may ask you to approve
the key on first launch.

## Work on a project

After building the checkpoint, run from your project directory:

```sh
cd /absolute/path/to/project
shuru run --from claude-code --memory 4096 --allow-net \
  --secret CLAUDE_CODE_OAUTH_TOKEN=CLAUDE_CODE_OAUTH_TOKEN@api.anthropic.com \
  --allow-host-writes --mount .:/workspace:rw \
  -- sh -c 'cd /workspace && exec claude'
```

Omit `:rw` and `--allow-host-writes` for a disposable project copy. With
`:rw`, agent edits reach your host project. Claude's normal tool permission
checks remain enabled.

## Persist interactive login and sessions

The launcher defaults `CLAUDE_CONFIG_DIR` to `/root/.claude` (Shuru's default
`HOME` is `/`). To keep login/configuration/session state between runs, use
a dedicated host directory:

```sh
mkdir -p "$HOME/.local/share/shuru/auth/claude-code"
chmod 700 "$HOME/.local/share/shuru/auth/claude-code"
cd "$HOME"
shuru run --from claude-code --memory 4096 --allow-net \
  --allow-host-writes \
  --mount "$HOME/.local/share/shuru/auth/claude-code:/root/.claude:rw" \
  -- claude auth login
```

Open the printed URL in your host browser and paste the login code into the
terminal if prompted. Reuse the same mount to run `claude`. This mode makes
the saved credentials readable inside the VM and lets Claude refresh them;
proxy-token mode above keeps the credential on the host. Keep this directory
outside source control and out of shareable checkpoints. Override
`CLAUDE_CONFIG_DIR` inside the guest if you need a different state directory.

Shuru only permits host mounts beneath the directory you launch it from.
The login example launches from your home directory for that reason. To
mount both auth state and a project, launch from a common parent of both
directories and mount each explicitly; only the listed directories are shared.
Interactive terminal sessions require Shuru 0.11.0 or later.

References: [authentication](https://code.claude.com/docs/en/authentication),
[installation and binary verification](https://code.claude.com/docs/en/setup),
[proxy certificates](https://code.claude.com/docs/en/network-config).
