# Shuru recipes

Official recipes for [Shuru](https://github.com/superhq-ai/shuru). A recipe
turns the base image, or an existing checkpoint, into a new checkpoint:
install things, declare services that start at boot, pull what the sandbox
needs so it can run offline afterwards.

```sh
shuru recipe list
shuru recipe show docker
shuru run --recipe docker -p 8080:8080 -- docker run --rm -p 8080:8080 nginxinc/nginx-unprivileged:1.31.7-alpine-slim
shuru run --recipe browser -p 9222:9222 -- sleep infinity   # headless Chromium, CDP on the host port
```

The first `shuru run --recipe` builds the checkpoint, later runs boot it
directly. Recipes are resolved to an exact commit and the checkpoint
records which one it came from. Use `--from NAME` to reuse an installed
checkpoint without checking the catalog for changes.

## Run coding agents

Use Shuru **0.11.0 or later** for interactive terminal sessions. Build either
agent without credentials:

```sh
shuru run --recipe claude-code --memory 4096 -- claude --version
shuru run --recipe codex --memory 4096 -- codex --version
```

Model requests require `--allow-net` at runtime. These recipes build
checkpoints containing the installed software; supply authentication when
you run an agent. Choose one authentication method per run:

| Agent | API key | Subscription |
|---|---|---|
| Claude Code | Host `ANTHROPIC_API_KEY` through `--secret` | Host `CLAUDE_CODE_OAUTH_TOKEN` through `--secret`, or persistent browser login |
| Codex | Host `OPENAI_API_KEY` through `--secret` | ChatGPT device login with a dedicated auth directory |

### Claude Code: Claude subscription

If Claude Code is installed on your host, run `claude setup-token`, then
save the generated token in your host environment as
`CLAUDE_CODE_OAUTH_TOKEN`. Run a prompt:

```sh
shuru run --recipe claude-code --memory 4096 --allow-net \
  --secret CLAUDE_CODE_OAUTH_TOKEN=CLAUDE_CODE_OAUTH_TOKEN@api.anthropic.com \
  -- claude -p 'Reply with exactly SHURU_OK' --model haiku
```

For an interactive coding session, run from your project directory:

```sh
cd /absolute/path/to/project
shuru run --from claude-code --memory 4096 --allow-net \
  --secret CLAUDE_CODE_OAUTH_TOKEN=CLAUDE_CODE_OAUTH_TOKEN@api.anthropic.com \
  --allow-host-writes --mount .:/workspace:rw \
  -- sh -c 'cd /workspace && exec claude'
```

Shuru gives the guest a placeholder and substitutes the real token only
on HTTPS requests to `api.anthropic.com`. Renew the host token when it
expires. For browser login inside the VM and persistent sessions, see the
[Claude Code login instructions](claude-code/README.md#persist-interactive-login-and-sessions).

### Claude Code: Anthropic API key

Set `ANTHROPIC_API_KEY` in your host environment, then:

```sh
shuru run --recipe claude-code --memory 4096 --allow-net \
  --secret ANTHROPIC_API_KEY=ANTHROPIC_API_KEY@api.anthropic.com \
  -- claude -p 'Reply with exactly SHURU_OK' --model haiku
```

Use this `--secret` option in the interactive project example to use API
billing instead of your Claude subscription.

### Codex: ChatGPT subscription

After building the Codex checkpoint above, create a dedicated login
directory. Launch from your home directory so the auth mount is beneath
your current working directory:

```sh
mkdir -p "$HOME/.local/share/shuru/auth/codex"
chmod 700 "$HOME/.local/share/shuru/auth/codex"
cd "$HOME"
shuru run --from codex --memory 4096 --allow-net \
  --allow-host-writes \
  --mount "$HOME/.local/share/shuru/auth/codex:/root/.codex:rw" \
  -- codex login --device-auth
```

Open the printed link in your host browser and enter the code. You may
need to enable device-code login in your ChatGPT security settings or
through your workspace administrator. Reuse the same auth mount for an
interactive session, replacing `./Projects/your-project` with your project:

```sh
cd "$HOME"
shuru run --from codex --memory 4096 --allow-net \
  --allow-host-writes \
  --mount "$HOME/.local/share/shuru/auth/codex:/root/.codex:rw" \
  --mount ./Projects/your-project:/workspace:rw \
  -- sh -c 'cd /workspace && exec codex'
```

The auth directory survives disposable VM runs and lets Codex refresh its
tokens. Its credentials are readable inside the VM; keep it outside your
project and source control. A file-based existing Codex `auth.json` can
also be copied into this dedicated directory.

### Codex: OpenAI API key

Set `OPENAI_API_KEY` in your host environment, then:

```sh
shuru run --recipe codex --memory 4096 --allow-net \
  --secret OPENAI_API_KEY=OPENAI_API_KEY@api.openai.com \
  -- sh -ec 'printenv OPENAI_API_KEY | codex login --with-api-key
    exec codex exec --skip-git-repo-check "Reply with exactly SHURU_OK" < /dev/null'
```

Codex saves only the proxy placeholder in the disposable guest. Repeat
this login on each API-key run, since placeholders belong to a particular
VM run. Closing guest stdin with `< /dev/null` prevents a scripted prompt
from waiting for additional piped input. API keys use OpenAI Platform
billing, separately from your ChatGPT subscription.

### Files, sessions, and permissions

- `--mount .:/workspace:rw` writes agent edits back to your host project
  and requires `--allow-host-writes`. Omit `:rw` for a disposable copy;
  guest edits to that mount are discarded on exit.
- Shuru only permits host mounts beneath your launch directory. When
  mounting auth state and a project together, launch from a common parent
  of both. Only the explicitly mounted directories are shared.
- Unmounted login state, configuration, and sessions disappear when the VM
  exits. Persistent state lives at `/root/.claude` for Claude Code and
  `/root/.codex` for Codex; use dedicated writable mounts when needed.
- The examples retain each agent's normal tool permissions and sandbox
  behavior. Mounting a writable project does not disable those checks.

More details: [Claude Code](claude-code/README.md) · [Codex](codex/README.md).

### Test the recipes

From a checkout of this repository, run:

```sh
bash scripts/smoke-agents.sh
```

This builds both agents, verifies fresh offline boots, and checks auth with
synthetic proxy credentials. It does not read personal credentials or make
model calls. The prompt examples above provide optional live smoke tests
using your own account.

## Layout

```
docker/
  recipe.json     metadata, services, step list
  install.sh      step 1
  pull.sh         step 2
browser/
  recipe.json
  install.sh      Chromium from Debian, an unprivileged user
  check.sh        proves the service answers and renders offline
claude-code/
  recipe.json
  install.sh      pinned native binary and runtime launcher
  check.sh        checks installation after a fresh boot
  README.md       authentication and project usage
codex/
  recipe.json
  install.sh      pinned npm release and runtime launcher
  check.sh        checks installation after a fresh boot
  README.md       authentication and project usage
scripts/
  validate.sh     validates the catalog and recipe manifests
  smoke-agents.sh builds and checks both coding agents
index.json        the catalog shown by `shuru recipe list`
```

`recipe.json`:

| field | meaning |
|---|---|
| `name` | checkpoint name for `shuru run --recipe`; `[a-z0-9][a-z0-9._-]*` |
| `description` | one line for the catalog |
| `min_shuru_version` | refuse to build on an older CLI |
| `from` | start from this checkpoint instead of the base image |
| `cpus`, `memory`, `disk_size` | VM size for the build |
| `network.allow` | hosts the build may reach; absent means offline, empty list means unrestricted |
| `services` | files written to `/etc/shuru/services/` before the first step |
| `steps` | scripts run in order, each in a fresh boot of the previous result |

Each step runs as root with `sh`. From the second step on, declared
services are running, so a step can use the daemon the first step
installed.

## Writing a recipe

1. Copy an existing directory and edit it. Pin everything you install:
   package versions, signing keys, image digests. The point of a recipe is
   that two people building it get the same checkpoint. Packages from the
   Debian archive itself are the exception: Debian keeps only the newest
   build in a suite, so pin those by enabling the security archive and
   printing the installed version, as the browser recipe does.
2. Test it locally without pushing: `shuru run --recipe ./docker -- ...`.
3. Add it to `index.json` and run `scripts/validate.sh`.
4. Open a pull request.

Recipes from other repositories work the same way:
`shuru run --recipe owner/repo/path --yes`.

## License

Apache-2.0, like Shuru.
