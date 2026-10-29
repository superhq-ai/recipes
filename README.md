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

Agent recipes are also available in the official catalog:

```sh
shuru run --recipe claude-code --memory 4096 -- claude --version
shuru run --recipe codex --memory 4096 -- codex --version
```

See [Claude Code](claude-code/README.md) and [Codex](codex/README.md) for
runtime API-key injection, subscription login, and persistent state. Agent
checkpoints contain installed software, never your login credentials.

Run `bash scripts/smoke-agents.sh` on a machine with Shuru to build both,
verify fresh offline boots, and check authentication with synthetic proxy
credentials. It does not read personal credentials or make model calls.

The first `shuru run --recipe` builds the checkpoint, later runs boot it
directly. Recipes are resolved to an exact commit and the checkpoint
records which one it came from.

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
