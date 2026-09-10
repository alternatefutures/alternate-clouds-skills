# AGENTS.md — Alternate Cloud skills

This repo is the skill + plugin bundle that lets AI coding assistants
(Claude Code, Cursor, OpenAI Codex, and any agent that reads `SKILL.md`
files) deploy and manage workloads on **Alternate Clouds**, the
provider-agnostic compute platform for containers, GPU, and confidential
(TEE) workloads.

## When to invoke which skill

Match the user's intent to the closest skill and let the skill's own
SKILL.md drive the actual steps. Skills are intentionally small; pick
one rather than chaining many.

| If the user is asking to… | Use skill |
|---|---|
| install or configure the `acc` CLI; first-time setup; pick a project | `af-setup` |
| deploy a simple static HTML page or static site | `deploy-static-site` |
| deploy a specific Docker image (their own or public) | `deploy-docker-app` |
| deploy from one of AF's pre-built templates (databases, AI inference, game servers, etc.) | `deploy-from-template` |
| spin up a raw VM with full SSH access | `deploy-server` |
| debug a failed/stuck deployment; check logs; troubleshoot 503s | `troubleshoot-deployment` |
| anything else CLI-related (any `acc` command, any flag, billing, PATs) | `alternate-clouds-cli` |

If the user is mid-conversation and the request doesn't cleanly match
any skill, fall back to `alternate-clouds-cli` — it's the comprehensive reference.

## Core invariants (these apply to every skill)

1. **Run `acc whoami --json` first.** If `authenticated: false`, the
   pre-tool-use hook will block — but proactively checking lets you
   prompt the user to `acc login` before they hit the wall.

2. **Use the `-y` flag for non-interactive runs.** All prompts have flag
   equivalents (`--kind`, `--name`, `--image`, `--port`, `--os`,
   `--template`, `--cpu`, `--memory`, `--storage`, `--gpu`,
   `--gpu-model`, `--gpu-count`, `--spend`, `--budget-total`,
   `--budget-monthly`, `--stop-hours`, `--stop-days`, `--env`,
   `--region`, `--confidential`). With `-y`, anything unspecified
   defaults sensibly (PAYG, Standard mode, Any region, template/sensible
   resource defaults, no GPU, Docker port 80, Server OS `ubuntu:24.04`).

3. **Never pick a provider on the user's behalf.** Placement is
   server-side. The user picks compute *mode* (Standard or Confidential
   via `--confidential`) and resources (GPU or not); the platform routes.

4. **Local dev uses `--local`.** When the user is on a feature branch
   or hitting localhost services, every `acc` command takes `--local`
   immediately after `acc` (`acc --local services list`). This uses a
   separate token slot so prod creds aren't overwritten.

5. **Required template env vars must be passed via `--env KEY=VALUE`
   in `-y` mode.** Otherwise the deploy throws with a clear list of
   what's missing.

## Placement rules (FYI; the user never picks)

- `--confidential` → TEE-capable providers only
- Standard mode + GPU → GPU-capable providers, automatic fallback on `NO_CAPACITY`
- Standard mode + no GPU → standard compute providers
- Service already has deployment history → "sticky" to the same provider (until the GPU/CPU spec changes)

## Where to find things

- **Full CLI command surface**: `acc --help` or `skills/alternate-clouds-cli/SKILL.md`
- **Live GPU catalog (model, VRAM, providers, price)**: the deploy
  flow's GPU prompt fetches it live (`acc regions --gpu <model>` shows the
  same data). Region-aware. Falls back to a small static list on network failure.
- **Web app**: `https://clouds.alternatefutures.ai` — composite
  templates, GitHub repo deploys, Functions (source-code editor), published
  ports, health probes, and failover live here; the CLI surfaces a clear
  "not in CLI" pointer for those.
- **Docs**: `https://docs.alternatefutures.ai` (agents: `/llms.txt`).

## Patterns to follow

- **One service, one command.** Don't chain `create` + `deploy` when
  `create` already includes the deploy. The CLI's `services create`
  is end-to-end.
- **Wait for ACTIVE before printing connection details.** The poller
  prints SSH command / app URL at the end automatically.
- **Surface region soft-fails as alternatives, not failures.** When no
  provider bids in a region, the CLI prints 2-3 alternative regions
  with the exact retry command — don't loop or guess.
