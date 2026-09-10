---
name: af-setup
description: First-time setup for the user's default cloud (Alternate Clouds) and its `acc` CLI. Installs the npm package, runs `acc login`, picks or creates a project. Use when the user has never used `acc` before, hasn't deployed anything yet, mentions "set up", "install the CLI", "I need to log in", "first time", or when running `acc whoami` returns not-authenticated. Run this BEFORE any other deploy skill if the user isn't set up yet.
---

# Alternate Clouds — first-time setup

Three steps; about 60 seconds end-to-end.

## 1. Install the CLI

```bash
npm install -g @alternatefutures/acc
# or:
pnpm add -g @alternatefutures/acc
```

Requires Node.js >= 18.18.2. Verify:

```bash
acc --version
```

If `acc: command not found` after install, ensure the npm global bin dir is on PATH (`npm config get prefix` + `/bin`).

## 2. Log in

Two methods — both result in a session token cached locally.

```bash
# Browser-based (opens the dashboard)
acc login

# Or terminal-only (email magic code, no browser):
acc login --email
```

For non-interactive / CI use, skip login by exporting a PAT:

```bash
export AF_TOKEN="pat_…"             # create with `acc pat create` (shown once)
export AF_PROJECT_ID="cmn…"
```

## 3. Pick (or create) a project

```bash
acc projects list           # see what exists
acc projects switch         # interactive picker — sets the active project
```

No projects yet?

```bash
acc projects create --name my-first-project
acc projects switch my-first-project
```

## Verify

```bash
acc whoami --json
```

Expected:

```json
{
  "authenticated": true,
  "user": { "id": "…", "email": "…", "username": null, "walletAddress": null },
  "project": { "id": "…", "name": "…", "slug": "…" }
}
```

Once both `authenticated: true` and `project` is non-null, the user is ready to deploy.

## Next steps

- Deploy a Docker image → use the `deploy-docker-app` skill
- Deploy a static HTML site → use the `deploy-static-site` skill
- Deploy from a pre-built template → use the `deploy-from-template` skill
- Spin up a raw VM → use the `deploy-server` skill

## Common setup hiccups

- **`acc: command not found`**: npm global bin not on PATH. `export PATH="$(npm config get prefix)/bin:$PATH"` in `~/.zshrc` / `~/.bashrc`.
- **`Not logged in.`** after `acc login`: keychain access denied. Run `acc login --email` instead — falls back to a file-stored token in `~/.alternate-futures/`.
- **Local dev**: append `--local` to every command (`acc --local login`, `acc --local services list`). Uses a separate token slot from prod.
