# Alternate Cloud — AI assistant plugin

One plugin, three platforms. Lets Claude Code, Cursor, and OpenAI Codex
deploy and manage workloads on **[Alternate Clouds](https://clouds.alternatefutures.ai)**,
the provider-agnostic compute platform for containers, GPU and confidential
workloads, through natural language.

Bundles the `acc` CLI reference plus task-specific skills for static
sites, Docker apps, templates, raw servers, and troubleshooting. The
assistant picks the right skill and walks the user (or itself) through
the deploy end-to-end.

## What's inside

| Skill | When it triggers |
|---|---|
| `alternate-clouds-cli` | Comprehensive `acc` CLI reference. Catch-all for any command/flag question. |
| `af-setup` | First-time install + `acc login` + project pick. |
| `alternate-chat` | Send, read, and participate in end-to-end encrypted `acc chat` rooms. |
| `deploy-static-site` | "Put my HTML / SPA build online." |
| `deploy-docker-app` | "Deploy my Docker image." |
| `deploy-from-template` | "Spin up Postgres / Ollama / Redis / ..." |
| `deploy-server` | "I need a VM to SSH into." |
| `troubleshoot-deployment` | "Why is my service 5xx / stuck / crashing?" |

Plus:

- `AGENTS.md` — Codex's per-project rules entry point
- `hooks/ensure-af-ready.sh` — Claude Code `PreToolUse` hook that verifies `acc` is installed + the user is logged in before any tool call
- `install.sh` — auto-detects which agent(s) you have installed and wires the skills correctly

## Install

The fastest path on any platform:

```bash
git clone https://github.com/alternatefutures/alternate-clouds-skills ~/.alternate-skills
bash ~/.alternate-skills/install.sh
```

`install.sh` detects `~/.claude/`, `~/.cursor/`, and `~/.codex/` (or `~/.agents/`) and symlinks each skill into the right place. Symlinks mean `git pull` in `~/.alternate-skills` updates every agent instantly.

Run for a single agent:

```bash
bash ~/.alternate-skills/install.sh claude   # or: cursor | codex
```

### Platform-specific install (alternatives)

#### Cursor — marketplace

Available on the [Cursor Marketplace](https://cursor.com/marketplace):

```
/add-plugin alternate-cloud
```

#### Claude Code — plugin marketplace

```
/plugin marketplace add https://github.com/alternatefutures/alternate-clouds-skills
/plugin install alternate-cloud@alternate-cloud
```

#### OpenAI Codex — git clone

Codex has no central marketplace. Clone the repo and let `install.sh` set up the symlinks:

```bash
git clone https://github.com/alternatefutures/alternate-clouds-skills ~/.alternate-skills
bash ~/.alternate-skills/install.sh codex
```

This symlinks each `skills/<name>/` into `~/.agents/skills/<name>/`, so Codex auto-discovers them by description.

### Manual (any agent)

If your agent doesn't fit the above, copy each `skills/<name>/SKILL.md` into the agent's skills directory:

- Cursor: `~/.cursor/skills/<name>/SKILL.md`
- Claude Code: `~/.claude/skills/<name>/SKILL.md`
- Codex: `~/.agents/skills/<name>/SKILL.md`

## Prerequisites

- Node.js >= 18.18.2
- The `acc` CLI itself: `npm install -g @alternatefutures/acc`
- A logged-in session: `acc login`

The `PreToolUse` hook in this plugin blocks any tool call that invokes `acc` if the CLI isn't installed or the user isn't authenticated — with a clear hint on what to run.

## Updating

```bash
cd ~/.alternate-skills && git pull
```

That's it — symlinks point at the repo, so all agents pick up new skills immediately.

## Adding your own skill

Drop a new directory under `skills/<your-name>/` containing a `SKILL.md` with this frontmatter:

```yaml
---
name: your-skill-name
description: A short, intent-matching description so agents auto-trigger this skill correctly.
---
```

Then re-run `install.sh` (or just the agent's skills dir will auto-pick it up if symlinked).

## Repo layout

```
alternate-clouds-skills/
├── README.md
├── LICENSE
├── AGENTS.md                # Codex root rules
├── install.sh               # auto-detect + symlink installer
├── mcp.json                 # MCP server registration (empty placeholder)
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── .cursor-plugin/
│   └── plugin.json
├── hooks/
│   ├── hooks.json           # Claude Code hook registration
│   └── ensure-af-ready.sh   # PreToolUse: acc installed + logged in
└── skills/
    ├── alternate-clouds-cli/SKILL.md
    ├── af-setup/SKILL.md
    ├── alternate-chat/SKILL.md
    ├── deploy-static-site/SKILL.md
    ├── deploy-docker-app/SKILL.md
    ├── deploy-from-template/SKILL.md
    ├── deploy-server/SKILL.md
    └── troubleshoot-deployment/SKILL.md
```

## Links

- CLI on npm: [@alternatefutures/acc](https://www.npmjs.com/package/@alternatefutures/acc)
- Platform: [alternatefutures.ai](https://alternatefutures.ai)
- Docs: [docs.alternatefutures.ai](https://docs.alternatefutures.ai) (agents: [/llms.txt](https://docs.alternatefutures.ai/llms.txt))

## License

AGPL-3.0-only
