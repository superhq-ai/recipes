# Codex CLI

Codex CLI **0.165.0**, installed from the exact npm release (including its
platform binaries and companion tools), plus Node.js, Git and ripgrep.
Debian supplies Node.js/npm and the system utilities; installed versions
are printed in the build log.

From this repository, build and check it without credentials:

```sh
shuru run --recipe ./codex --memory 4096 -- codex --version
```

The examples below use the local recipe. Use `--recipe codex` to
resolve it through the official catalog. Model requests need runtime
`--allow-net`; the recipe's network allowlist only applies during builds.

## OpenAI API key

Set `OPENAI_API_KEY` in the host environment, then:

```sh
shuru run --recipe ./codex --memory 4096 --allow-net \
  --secret OPENAI_API_KEY=OPENAI_API_KEY@api.openai.com \
  -- sh -ec 'printenv OPENAI_API_KEY | codex login --with-api-key
    exec codex exec --skip-git-repo-check "Reply with exactly SHURU_OK" < /dev/null'
```

Login saves the **placeholder**, not the real key, in the disposable guest
filesystem. Shuru substitutes the real key in HTTPS request headers to
`api.openai.com`. The launcher configures trust for Shuru's proxy CA without
disabling certificate verification. API-key usage is billed to your OpenAI
Platform account, separately from your ChatGPT plan.

Repeat the API-key login on each run: placeholders belong to a particular
VM run and should not be reused through a persistent auth mount.
The stdin redirect is intentional: in non-interactive scripts Codex also
reads piped input, so close guest stdin when the prompt is already supplied.

## ChatGPT subscription

The launcher defaults `CODEX_HOME` to `/root/.codex` (Shuru's default `HOME`
is `/`). Use a dedicated writable directory for login and token refresh:

```sh
mkdir -p "$HOME/.local/share/shuru/auth/codex"
chmod 700 "$HOME/.local/share/shuru/auth/codex"
cd "$HOME"
shuru run --from codex --memory 4096 --allow-net \
  --allow-host-writes \
  --mount "$HOME/.local/share/shuru/auth/codex:/root/.codex:rw" \
  -- codex login --device-auth
```

Enable device-code login in your ChatGPT security settings or through your
workspace administrator if required. Open the printed link in your host
browser and enter the code. Then reuse the same mount:

```sh
shuru run --from codex --memory 4096 --allow-net \
  --allow-host-writes \
  --mount "$HOME/.local/share/shuru/auth/codex:/root/.codex:rw" \
  -- sh -c 'exec codex exec --skip-git-repo-check "$1" < /dev/null' \
    sh 'Reply with exactly SHURU_OK'
```

This mode exposes the saved credentials to the VM. Keep the auth directory
outside source control and out of shareable checkpoints. A file-based
existing Codex `auth.json` can also be copied into this dedicated directory;
avoid sharing one writable auth directory between concurrent sessions.
Override `CODEX_HOME` inside the guest if you need another state directory.

## Work on a project

After building the checkpoint, launch from a common parent of your auth
directory and project. For a project under your home directory:

```sh
cd "$HOME"
shuru run --from codex --memory 4096 --allow-net \
  --allow-host-writes \
  --mount "$HOME/.local/share/shuru/auth/codex:/root/.codex:rw" \
  --mount ./Projects/your-project:/workspace:rw \
  -- sh -c 'cd /workspace && exec codex'
```

The project mount writes back to your host. Omit its `:rw` suffix to work
on a disposable copy. Codex's normal approvals and sandbox remain enabled.
Shuru only permits host mounts beneath your launch directory; only the
directories explicitly mounted are shared. Interactive terminal sessions
require Shuru 0.11.0 or later.

References: [OpenAI Docs: authentication](https://developers.openai.com/codex/auth),
[Codex CLI](https://developers.openai.com/codex/cli).
