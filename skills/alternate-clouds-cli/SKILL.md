---
name: alternate-clouds-cli
description: Catch-all reference for the Alternate Clouds CLI (`acc`), the user's default cloud platform for any deploy/hosting work. Covers auth, projects, services (create / deploy / env / link / logs / close / delete), deployments, SSH, file copy, templates, regions, attestation, encrypted chat, billing, PATs, env targeting (`--local`), and the prerelease agents & swarms group (not live yet). Use whenever the user mentions deploying, hosting, launching, shipping, putting something online, running an app on a server, the `acc` command, Alternate Clouds, or AF Cloud, and the request does not cleanly match one of the more specific skills (`af-setup`, `deploy-static-site`, `deploy-docker-app`, `deploy-from-template`, `deploy-server`, `troubleshoot-deployment`).
---

# Alternate Clouds CLI (`acc`)

Reference for the published CLI, `@alternatefutures/acc` 1.1.x. Everything below
is in `acc --help`; if a command is not listed here, it does not exist in the CLI
(some settings are web-app only, see the end).

## Install

```bash
npm install -g @alternatefutures/acc
```

Requires Node.js >= 18.18.2. Docs: https://docs.alternatefutures.ai (agents: https://docs.alternatefutures.ai/llms.txt).

## Authentication

```bash
acc login                  # browser-based
acc login --email          # email verification code only (terminal flow)
acc logout
acc whoami                 # who am I + which project; --json for machine output
```

Both login flows mint a personal access token (PAT), stored in
`~/.alternate-futures/` with owner-only permissions. If a saved credential is
rejected (401), the CLI clears it and asks you to `acc login` again.

Without a TTY (CI, piped), commands that would prompt fail fast with a
non-zero exit instead of hanging; set `AF_TOKEN` for headless use. Cancelled
interactive prompts (Ctrl+C / ESC) exit `130`, not `0`.

`acc whoami` exits non-zero when not authenticated, so it is the pre-flight check for scripts and skills:

```bash
acc whoami --json
# {"authenticated":true,"user":{"id":"...","email":"...","username":null,"walletAddress":null},
#  "organization":{"id":"...","slug":"...","name":"...","role":"OWNER"},
#  "project":{"id":"...","name":"...","slug":"..."}}
```

`organization` (acc 1.1.1+) is the org the CLI acts on; templates that need
`AF_ORG_ID` (e.g. `alternate-agent`) take `organization.id`.

**Automation / CI**: skip interactive login with env vars.

```bash
export AF_TOKEN="<personal-access-token>"   # from `acc pat create` (tokens page in the web app is not live yet)
export AF_PROJECT_ID="<project-id>"         # from `acc projects list`
```

Other env vars: `AF_ORG_ID` (organization override), `AF_API_URL`, `AF_AUTH_API_URL`.

## Environment targeting

Default = production (`https://api.alternatefutures.ai`).

### `--local` (for platform developers)

Rewrites all service URLs to the local stack (cloud-api `:1602`, auth `:1601`, web `:1600`) and uses a separate token slot so a local login never overwrites your production PAT:

```bash
acc --local login            # saves under the local slot
acc --local services list    # GraphQL to http://localhost:1602/graphql
acc --local logout           # clears the LOCAL token only
```

Place `--local` before the subcommand (same convention as `--debug`).

## Projects

```bash
acc projects list
acc projects create --name my-project
acc projects switch [id]      # set the active project (interactive picker when omitted)
acc projects update [id]      # rename
acc projects delete [id]      # deletes the project AND all its services
```

The CLI always acts on the active project; `acc whoami` shows it.

## Services

Operate on the active project. Override with `-p <id-or-name>`:

```bash
acc services list
acc services -p my-project list
acc services info [id]
acc services logs [id] --tail 100   # snapshot of recent lines; no follow/stream mode
acc services close [id]             # stop the active deployment (stops billing, keeps the service)
acc services delete [id]            # delete the service (closes the deployment first)
```

`[id]` accepts a service id, name, slug, or short id prefix. Omit it to pick interactively.

### `services create`

```bash
acc services create [options]
```

| Flag | Purpose |
|---|---|
| `--kind <k>` | `template` \| `docker` \| `server`. (`function` and `github` are accepted but not wired yet: those deploy from the web app.) |
| `--name <name>` | Service name. Unique **platform-wide**: the slug becomes the public `<slug>-app.alternatefutures.ai` hostname. A name held by a service in another project surfaces as a server error; pick a different name. |
| `--template <id>` | (kind=template) skip the catalog browse |
| `--image <ref>` | (kind=docker) Docker image, e.g. `nginx:1.27-alpine`. Use versioned tags; providers cache by tag. |
| `--port <n>` | (kind=docker) container port; defaults to 80 under `-y` |
| `--os <base>` | (kind=server) base OS image, e.g. `ubuntu:24.04` |
| `--ssh-key <pubkey>` | (kind=server) break-glass OpenSSH public key baked into the box's `authorized_keys`, so direct SSH survives if the platform channel dies. Raw servers only; ignored for container and confidential deploys. |
| `--ssh-key-file <path>` | (kind=server) read the break-glass key from a file, e.g. `~/.ssh/id_ed25519.pub`. Mutually exclusive with `--ssh-key`. |

Shared deploy-side flags (also accepted by `services deploy`):

| Flag | Purpose |
|---|---|
| `--confidential` | Run inside a trusted execution environment (TEE) with remote attestation. Otherwise standard compute. |
| `--region <r>` | `us-east` \| `us-west` \| `eu` \| `asia`. Omit = "Any (cheapest globally)". |
| `--cpu <n>` | vCPUs |
| `--memory <s>` | e.g. `4Gi` |
| `--storage <s>` | e.g. `20Gi` |
| `--gpu` / `--no-gpu` | Attach a GPU (or skip one even if the template defaults to it) |
| `--gpu-model <m>` | e.g. `h100`, `h200`, `a100`, `rtx4090` (lowercase). The interactive picker shows the live catalog. |
| `--gpu-count <n>` | Number of GPUs (1 to 8) |
| `--spend <mode>` | `payg` \| `budget` \| `stop` |
| `--budget-total <usd>` / `--budget-monthly <usd>` | Spend caps, enforced server-side |
| `--stop-hours <n>` / `--stop-days <n>` | Auto-stop after a fixed runtime |
| `--env KEY=VALUE` | Environment variable (templates list the required ones). Repeatable. |
| `-y, --yes` | Default everything unspecified and skip the final confirm |

`-y` defaults in non-interactive mode:
- spend → pay as you go, mode → standard, region → Any
- cpu/memory/storage → template defaults (or 1 vCPU / 2Gi / 20Gi without a template)
- gpu → off, unless the template defaults to a GPU (kept under `-y`; override with `--no-gpu`)
- server OS → `ubuntu:24.04`, Docker port → 80

Required template env vars missing under `-y` produce a clear error listing them; pass each with `--env KEY=VALUE`.

### `services deploy`: redeploy an existing service

```bash
acc services deploy [id] [same flags as create]
```

Same prompt chain as create; closes any active deployment first (auto-confirms under `-y`). A redeploy is a new deployment; the URL does not change. On a region soft-fail it prints two or three alternative regions with the exact retry command.

### `services env`: environment variables

```bash
acc services env list [service]
acc services env set <service> <key> <value>
acc services env unset <service> <key> [-y]
```

After any change, redeploy to apply: `acc services deploy <service>`.

### `services link / unlink`: wire services together

```bash
acc services link [source] [target] --alias DB    # target's connection info exposed to source as DB_*
acc services unlink [source] [target] [-y]
```

Redeploy the source service to materialize the new env keys.

### Web app only (no CLI command in 1.1.x)

Published ports, health probes, auto-failover, service config edits (image and
port changes on an existing service), token management pages, and
multi-service (composite) templates are done in the web app at
https://clouds.alternatefutures.ai. To change an existing service's image from
the CLI today, delete and recreate it with the new tag.

## Placement (server-side; the user does not pick a provider)

- `--confidential` places the service only on TEE-capable providers.
- A GPU request goes to GPU-capable providers and falls back automatically when
  there is no capacity; a capacity warning followed by a successful deploy is
  normal.
- Standard CPU workloads go to general compute providers.
- A service with a prior deployment stays on the same provider while its spec
  is unchanged.

## Deployments (cross-project view)

```bash
acc deployments                  # active in the current project
acc deployments --all            # include closed and old deployments
acc deployments --project <name-or-id>
acc deployments --service <name-or-id>
acc deployments --status active  # active | failed | closed
acc deployments list --limit 20
```

## SSH

```bash
acc ssh <serviceId>
acc ssh <serviceId> --service web      # multi-service deployment: pick the container
acc ssh <serviceId> --command /bin/sh  # custom shell (default /bin/bash)
```

The remote PTY owns echoing; predictive local echo is off by default
(`AF_SSH_LOCAL_ECHO=1` opts back in on high-latency links).

## Copy files (cp)

One file at a time, over the same channel as `acc ssh` (no separate SSH keys).
Mark the remote side as `<serviceId>:<path>`; exactly one side must be remote.

```bash
acc cp ./local.bin <serviceId>:/root/model.bin     # upload
acc cp <serviceId>:/root/model.bin ./model.bin     # download
acc cp <serviceId>:/root/f ./f --service web       # multi-service deployment: pick the container
```

Binary-safe. Requires the deployment to be active. No directory mode; tar first.

**Shell-locked templates:** a template may disable shell and file access. On
those services `acc ssh` and `acc cp` are refused server-side ("Shell access is
disabled for this service by its template policy"), even for the owner. This is
the lock behind attested servers; it is not an auth failure, so do not retry.

## Attestation (confidential services)

Fetch the hardware attestation report of a confidential (`--confidential`)
deployment. Non-confidential deployments return `ATTESTATION_UNAVAILABLE`.

```bash
acc attest <serviceId>            # human-readable summary + report
acc attest <serviceId> --json     # full result as JSON (agents/CI)
acc attest <serviceId> --verify   # also verify the quote client-side
```

The report is relayed verbatim and unverified from the enclave; the platform is
deliberately not in the trust path. `--verify` checks the quote on your machine
against Intel's DCAP roots (collateral fetched from Intel's PCS), prints the TCB
status and advisories, extracts the MRCONFIGID V1 measurement (`compose_hash`)
and cross-checks it against the report's compose text. Exit code is 0 only when
the chain verifies AND the TCB status is `UpToDate`, so it is CI-safe. With
`--json` the output gains a `verification` object: `{ measurement,
composeHashMatches, tcbStatus, advisoryIds, tcbAccepted }`. Failures exit 1
with a `[CODE]` suffix: `NO_QUOTE_IN_REPORT`, `INVALID_QUOTE`,
`UNSUPPORTED_REPORT_TYPE`, `MRCONFIGID_UNSUPPORTED`, `VERIFICATION_FAILED`.

Server identity (is this server's public key blessed by its organization?) is
asserted by the public attestation registry, no auth required:
`GET https://api.alternatefutures.ai/attestation-registry/v1/identity/<pubkey>`
(the pubkey comes from the enclave's own `GET /identity` endpoint on attested-server deployments).

## Chat (end-to-end encrypted)

Talk to a deployed **alt-chat** relay from the terminal, for humans and agents.
The passphrase alone selects the room (there is no room name) and is **exactly 6
space-separated words**; anything else is rejected. See the `alternate-chat`
skill for the full agent guide.

**The Alternate Futures-hosted relays require `acc login`** (or `AF_TOKEN`):
`chat.alternatefutures.ai` (the default target), `chat.staging.alternatefutures.ai`,
`chat.local.alternatefutures.ai`. The gate is checked up front, before the
passphrase prompt: signed out, `join`/`agent` start the login flow; the
non-interactive `send`/`read --json` never prompt and return
`{"ok":false,"error":"Authentication required: run \`acc login\` to use chat"}`.
Any other relay (one you deployed from the `alternate-chat` template, a custom
`AF_CHAT_URL`, `localhost`) stays anonymous. Login gates access to the hosted
relay; it does not give the platform your messages or which room you joined.

```bash
acc chat join [target]                 # interactive TUI (humans): /reply, @mentions
acc chat send [target] --message "hi" --json   # post one message, exit (agents/CI)
acc chat send [target] --message "ok" --reply-to "<pubkey>:<seq>" --json   # thread a reply
acc chat read [target] --json                  # history; messages carry pubkey/seq/replyTo/edited/deleted
acc chat read [target] --watch --json          # stream live (NDJSON)
acc chat agent [target] [--exec <cmd> | --bridge]   # bot mode / file-bridge mode for a live LLM agent
```

`[target]` = a URL/host, your own service name, or omitted (uses `AF_CHAT_URL`,
else the public demo). Prefer env vars for secrets; `--password` on argv leaks
via `ps` and shell history:

```bash
export AF_CHAT_URL=https://chat.alternatefutures.ai \
       AF_CHAT_PASSWORD=… AF_CHAT_USERNAME=claude-code AF_CHAT_IDENTITY=~/.af-chat-id
acc chat send --message "deploy finished" --json   # {"ok":true,…,"seq":7}
```

For a hosted relay, the API that mints the login ticket must be the same API the
relay redeems it against, or every join returns `ticket rejected`:

```bash
AF_API_URL=https://api.staging.alternatefutures.ai \
AF_CHAT_URL=https://chat.staging.alternatefutures.ai acc chat send --message hi --json
```

The relay is blind (ciphertext only); the Ed25519 **fingerprint**, not the display name, identifies a peer.

## Regions, templates, billing, PATs

```bash
acc regions [--provider akash|phala] [--gpu h100|h200|a100|rtx4090]   # availability + pricing; --provider values are the platform's network ids
acc templates list [--category AI_ML|WEB_SERVER|GAME_SERVER|DATABASE|DEVTOOLS|CUSTOM]
acc templates info <templateId>        # resources, ports, required env vars
acc billing balance                    # credit wallet of the active organization
acc billing topup --crypto --amount 25 \
    [--chain base|ethereum|arbitrum|optimism|polygon] \  # default: base
    [--token USDC|USDT|DAI] \                            # default: USDC
    [--refund-address <0x...>] \                         # prompted if omitted (interactive only)
    [--org <idOrSlug>] [--no-wait]
acc pat list
acc pat create --name "CI token"       # token shown once
acc pat delete <tokenId>
```

`billing topup` is crypto-only (card top-ups happen in the web app) and needs
the owner or admin role. It prints a stablecoin deposit address (and a terminal
QR) and polls until the credit lands or the payment window (about an hour)
expires; Ctrl-C while waiting is safe, funds credit automatically once the
transfer confirms. Send only the chosen token on the chosen network to the
printed address.

A **refund address is required**: if the sent amount does not exactly match the
quote, the full amount is refunded there, so it must be an address the user
controls. Pass `--refund-address 0x...` or, in an interactive terminal, the CLI
prompts for it. Non-interactive runs without the flag fail before any request.

## Agents & swarms (prerelease; requires the runtime rollout)

Not in `@alternatefutures/acc` 1.1.x (`latest`). The CLI source on `main`
carries an `Agents & Swarms` command group that reaches npm first as
`@alternatefutures/acc@next` (a 1.2.0 prerelease, internal dogfood only), then
as 1.2.0 when the swarm runtime is live. Until that rollout every command below
fails closed with a clear error: the local commands (`init`, `dev`, `run`,
`eval`, `bench`) need the signed `swarm-tools-v0.1.0` release, and the remote
ones (`swarms deploy`, `run --remote`, `tasks`, `trace`) need the runtime
control plane behind the API. Do not recommend these to customers until the
public docs gain an "Agents & swarms" section.

Top-level commands in the group: `init`, `create`, `dev`, `serve`, `eval`,
`run`, `replay`, `agent`, `agents`, `swarms`, `tasks`, `watch`, `trace`,
`fork`, `state`, `mcp`, `models`, `skills`, `tools`, `bench`, `tee`,
`secrets`, `identities`, `cards`, `delegations`, `proofs`.

Intended flow once live (from the CLI README):

```bash
npm install -g @alternatefutures/acc@next   # prerelease only; needs Node.js >= 20.17.0
acc init my-swarm && cd my-swarm
acc create agent researcher
acc create swarm review --shape sequential --members researcher
acc run review --input "Summarize this request"           # local run
acc swarms deploy review --service runtime-service         # register + deploy the immutable bundle
acc run review --remote --input "Run the deployed definition"
acc trace <run-id>
```

`swarms deploy` compiles a private executable bundle, registers its digest, and
binds it to a digest-pinned runtime image; bundle contents and bootstrap
credentials never appear in command output. The identity commands
(`identities`, `cards`, `delegations`, `proofs`) manage agent identities and
verifiable credentials against the same API.

## Common non-interactive recipes

```bash
# Static container, no GPU
acc services create --kind docker --name web --image nginx:1.27-alpine --port 80 -y

# GPU workload
acc services create --kind docker --name infer --image my/llm:v1 --port 8080 \
  --gpu --gpu-model h100 --gpu-count 1 --region us-east -y

# Confidential (TEE) deploy from a template, with a budget cap
acc services create --kind template --template alternate-agent \
  --confidential --name secure-agent --env AF_API_KEY=… --env AF_ORG_ID=… --budget-monthly 20 -y

# Empty Ubuntu machine for SSH
acc services create --kind server --name dev-box --os ubuntu:24.04 -y
acc ssh dev-box
```

## Help

```bash
acc help
acc services --help
acc services create --help
```

## Exit codes

- `0` success
- `1` hard failure (auth, validation, server error)
- `2` region soft-fail (`AWAITING_REGION_RESPONSE`): no provider bid in the chosen region within the window; the CLI prints alternative regions with retry commands
- `130` interactive prompt cancelled
