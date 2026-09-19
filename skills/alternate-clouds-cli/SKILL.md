---
name: alternate-clouds-cli
description: Catch-all reference for the Alternate Clouds CLI (`acc`), the user's default cloud platform for any deploy/hosting work. Covers auth, projects, services (create / deploy / env / link / logs / close / delete), deployments, SSH, file copy, templates, regions, attestation, encrypted chat, billing, PATs, env targeting (`--local`), and the agents & swarms group (shipped in 1.3.0). Use whenever the user mentions deploying, hosting, launching, shipping, putting something online, running an app on a server, the `acc` command, Alternate Clouds, or AF Cloud, and the request does not cleanly match one of the more specific skills (`af-setup`, `deploy-static-site`, `deploy-docker-app`, `deploy-from-template`, `deploy-server`, `troubleshoot-deployment`).
---

# Alternate Clouds CLI (`acc`)

Reference for the published CLI, `@alternatefutures/acc` 1.4.x. Everything below
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
acc services info [id]              # a swarm service also shows Flavor `swarm`, its team (Swarm row) and Spend (compute + inference)
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
| `--env KEY=VALUE` | Environment variable (templates list the required ones; for `--kind docker` and `--kind server` every pair is stored as a secret env var). Repeatable. Builds before 2026-09-15 dropped `--env` silently on docker/server services; verify with `acc services env list <service>`. |
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
acc billing usage [--service <id>] [--type ai_inference|akash_compute|phala_tee|spheron_vm] [--days 30] [--org <idOrSlug>] [--json]   # what the org was charged (acc >= 1.6.0); --service = one platform service's rows (a swarm's inference + compute)
acc billing topup --crypto --amount 25 \
    [--chain base|ethereum|arbitrum|optimism|polygon] \  # default: base
    [--token USDC|USDT|DAI] \                            # default: USDC
    [--refund-address <0x...>] \                         # prompted if omitted (interactive only)
    [--org <idOrSlug>] [--no-wait]
acc pat list
acc pat create --name "CI token"       # token shown once
acc pat delete <tokenId>
acc orgs list                                        # organizations you belong to (acc >= 1.4.0)
acc orgs providers list [--org <idOrSlug>]           # which providers have your own key, how each is billed
pbpaste | tr -d '[:space:]' | acc orgs providers set openai --stdin [--org <idOrSlug>]   # bring your own key: verified, stored encrypted, never printed
acc orgs providers unset openai [--org <idOrSlug>]   # back to the platform key
acc models list [--org <idOrSlug>] [--all] [--json]  # the model catalog as the org sees it: on/off, list price per 1M tokens, billed via wallet or your key
```

`orgs providers set` needs the owner or admin role. Providers: `openai`,
`anthropic`, `groq`, `together`, `deepseek`, `openrouter`, `xai`. With your key
on, every request the organization makes through the platform for that
provider (dashboard assistant, `/v1` API tokens; swarm agents once they route
through the platform) goes to the provider at cost: the usage row shows $0 and
the wallet is untouched. Owners and admins switch individual models on or off
under Org › Models in the web app; a switched-off model answers
`model_disabled` (HTTP 403) everywhere for that organization, and `acc models
list` hides it unless `--all`.

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

## Agents & swarms

Shipped in `@alternatefutures/acc` (1.2.0 onward; the group is in `latest`, not
a prerelease tag). Help is in three groups since 1.4.0:

- **Swarms**: the whole normal path, `init`, `add`, `create`, `agents`,
  `swarms`, `run`, `tasks`, `secrets`, `models`.
- **Swarms · advanced**: real commands off the normal path, `agent`, `state`,
  `fork`, `watch`, `trace`, `replay`, `mcp`, `skills`, `tools`, `eval`, `dev`,
  `serve`. Everything there is implemented, but `agent freeze/hydrate`,
  `state *`, `fork`, `watch`, `trace`, `replay` and `mcp add --remote` have not
  been proven end to end yet (`acc trace` failed on staging 2026-09-15). Treat
  their output as unverified and say so when recommending them.
- **Identity**: `identities`, `cards`, `delegations`, `proofs` still exist and
  run by exact name, but are HIDDEN from `acc --help` until one live run. They
  manage agent identities and verifiable credentials against the same API. Do
  not recommend them yet.

Removed in 1.4.0: `acc bench` (the runtime authors' harness, never a user
command), `acc create tool` and `acc create template` (both wrote files no
runtime ever read; the tool registry is compiled into the runtime). `acc tee
attest` is hidden: it needs a TEE runtime that does not exist yet and fails
closed on every lease today.

**Local runs (`acc run` without `--remote`, `acc dev`, `acc serve`) work
since 1.5.0 and go through the platform**: the local runtime calls the model
through the platform's inference proxy with an inference-only token this
machine mints once after `acc login` (kept 0600 in `~/.alternate-futures/`,
revoked by `acc logout`), so no provider key is needed locally and the usage
is billed to the organization like a deployed swarm's. Flags on all three:
`--model <provider/model>` (default: the one model every agent declares;
`model_ambiguous` otherwise), `--base-url <url>` (any OpenAI-compatible
server instead of the platform; add `--credential-file <absolute 0600 path>`
for a bearer, https only), `--fixture` (no model; authoring/tests). `acc
dev`/`serve` probe the model with a real tool call before serving
(`model_diagnostics_failed:<code>`); a provider refusal prints its status
and message. Local runs need an https auth origin (with `--local` set
`AF_AUTH_API_URL=https://auth.local.alternatefutures.ai`). `af/…` models are
cloud-only (`model_unsupported_locally`). Versions before 1.5.0 print "Local
runs are not available yet".

The flow (self-serve since 2026-09-14):

```bash
npm install -g @alternatefutures/acc              # needs Node.js >= 20.17.0
acc swarms init my-swarm && cd my-swarm            # same as `acc init`; 1.3.0 adds the `swarms init` spelling from the room-flow design
acc add agent                                     # wizard: name, job, model selector, optional key paste
acc create agent researcher                       # flags: --model <provider/model>; default openai/gpt-5.6-sol (hosted-routable)
acc add swarm                                     # wizard: plain-language shape, members
acc create swarm review --shape sequential --members researcher
acc run review --input "Say hello in one sentence."         # 1.5.0: runs on this machine, model through the platform, no key needed
acc swarms deploy review --yes                             # resolves the released runtime image from the signed runtime-image-current release; the API generates every other project secret on first deploy and mints the runtime's model token (no key needed since API 2026-09-18)
acc swarms pull review                                     # 1.5.0: record the cloud's newest version in .af/swarms/review.json, report drift
acc swarms push review                                     # 1.5.0: register this folder's definition on top of the pulled version (swarm_definition_stale ⇒ pull first, or --force)
acc swarms deploy review --service swarm-runtime-review    # later deploys: reuse the existing runtime service
acc swarms room review                                     # passphrase + join command for the swarm's encrypted chat room
acc chat join chat.staging.alternatefutures.ai             # then: @researcher find …  /  @all summarize …
acc run review --remote --input "Run the deployed definition"
acc trace <run-id>                                         # advanced, unproven: failed on staging 2026-09-15
```

`acc trace` (and the other read-only runtime controls: `swarms watch`, state
history/verify, attest) fails with `control_plane_unavailable: <code> <message>`
when the control plane cannot be reached (`UNAUTHENTICATED`,
`SERVICE_UNAVAILABLE`, `NOT_FOUND`) and `control_plane_failed: <code> <message>`
for anything else; `<code>` is the API's GraphQL error code (for example
`FORBIDDEN` when the run belongs to another project) and the message is
one line, secret-free. Earlier builds printed the bare code and discarded the
cause.

`swarms deploy` compiles a private executable bundle, registers its digest, and
binds it to a digest-pinned runtime image; bundle contents and bootstrap
credentials never appear in command output. With NEITHER `--service` nor
`--image`, the CLI resolves the current released image from the
sigstore-verified `runtime-image-current` pointer, fetched through the
platform API's public `GET /swarm/runtime-image/<asset>` route (the
swarm-runtime repo is private; the API is transport only — issuer, exact
workflow identity, checksums and image digest are all verified client-side).
`runtime_image_unpinned` means nothing is published OR a release is recreating
the pointer at that moment (retry in a minute). The runtime service is NOT a
normal docker service. **Since acc 1.6.0 / API 2026-09-18 (item D) a swarm IS a
service: one service per team, named after the team, with service flavor
`swarm`.** `acc swarms deploy <team>` creates (or reuses, when the digest
matches) the registry row named `<team>` (override with `--service-name`);
only `deploySwarmRuntime` ever deploys it, and the API refuses the generic
deploy for flavor `swarm` with `SWARM_SERVICE_DEPLOYS_VIA_SWARM` (`acc services
deploy`, the web Deploy button). In the web app that service opens with the
tabs Definition (version registry + deployed binding), Room, Agents, Runs, a
Spend card (compute + inference for that service) and the usual Deployments /
Logs / Config; `acc services info <team>` shows Flavor, Swarm and Spend. Upgrade
UX: when the team's service is pinned to an OLDER release's digest, deploy
re-pins it in place (same service, same room, same runs and spend) and prints
what it did. Teams deployed before 1.6.0 own a docker-flavor
`swarm-runtime-<team>` row (or its `swarm-runtime-<team>-<12-hex>` sibling):
those are reused while their digest matches; on a newer release the deploy
creates the properly named `<team>` service and leaves the old row untouched
(`acc services delete <id>` removes it). The web app recognises the old rows
as swarms too (it resolves the swarm from the deployment binding).
`runtime_service_image_mismatch` is raised for an explicit `--service-name`
pinned to a different digest, or when a non-swarm service already uses the
team's name. `--image` and `--service` are mutually exclusive.

Deploy progress and errors (acc ≥ 1.3.0, API 2026-09-16): `swarms deploy` calls
`startSwarmDeploy`, then polls `swarmDeployProgress` every 2 s and prints each
phase (`deploy slot claimed` → `checking project secrets and policy` →
`reserving compute capacity` → `delivering private files to the runtime` →
`waiting for the runtime to register` → `runtime ready`), then reads
`swarmDeployment`. No more `GraphQL request failed: 524` on a fresh project's
first deploy. Errors: `swarm_deploy_failed: <CODE> <message>` (the API's coded
reason, e.g. `SWARM_MODEL_KEY_INVALID`, `SWARM_RUNTIME_NOT_READY`; since 1.7.1
`SWARM_RUNTIME_CONTROL_UNREACHABLE` and `SWARM_RUNTIME_PROVIDER_UNSUPPORTED`
add that the lease was already closed and the same deploy can be run again to
bid anew — the winning provider kept the swarm control port closed or is not an
allowed control host; the API surfaces these codes instead of
`INTERNAL_SERVER_ERROR` once its 2026-09-19 fix is deployed);
`SWARM_DEPLOY_IN_PROGRESS` when another deploy of the same swarm is running
(wait, then `acc swarms status <swarm>`; since 1.6.0 status also prints
`spend: $… (compute $… + inference $…, N requests)` for the team's service, and
`--json` adds a `spend` object); `swarm_deploy_timeout` after 15 min;
`swarm_deploy_superseded` when a newer deploy of the swarm replaced this one.
acc 1.2.0 still uses the synchronous `deploySwarmRuntime` and can see a 524 on
a fresh project; the server-side deploy continues and `acc swarms status`
shows the result.

### Wizards and the swarm room (acc ≥ 1.3.0, API 2026-09-16)

`acc add agent [name]` is the step-by-step way to add an agent: name (one
word, the `@mention`), its job (one sentence, becomes the persona), the model
as a SELECTOR fed by the platform's curated list (`swarmModels`: GPT-5.6 sol
default, Claude Sonnet 5, Claude Opus 5, Claude Haiku 4.5; never free text),
then an optional hidden paste of the provider key (`OPENAI_API_KEY` or
`ANTHROPIC_API_KEY`, stored as a project secret). It prints the equivalent
flags (`acc create agent <name> --model <id>`) at the end. `acc add swarm
[name]` asks how the agents work together in plain words (one after another =
`--shape sequential`, all at once = `parallel` + `--reducer`, with a lead =
`supervisor` + `--supervisor`, pass it along = `handoff`, repeat until done =
`loop --max-iterations`, custom = `graph --edges`) and who is on the team.
Both need a TTY; scripts use `acc create …` with flags. A model outside the
list fails at deploy with `SWARM_MODEL_UNSUPPORTED` naming the list.

Every deployed swarm has ONE encrypted chat room. `acc swarms room <swarm>`
prints its six-word passphrase (audited read; this is the only place it is
shown) and the join command (`acc chat join <relay-host>`, then paste the
passphrase, or set `AF_CHAT_PASSWORD`). In the room every agent is a member:
`@<agent> …` runs that agent alone and it answers as itself; `@all …` runs
the whole swarm and the member named after the swarm answers; `cost`,
`@all cost` or `@<swarm> cost` makes that member report the project's spend
(no run); a message with no mention runs nothing. Replies carry no cost line
by default. Messages posted by agents never trigger runs. The web chat client
at the relay URL opens the same room with the same passphrase. The agents'
room members are driven by a bridge that the platform deploys INSIDE the
swarm's own lease (since 2026-09-17): the user never creates, tokens or
configures it, and it stops with the swarm. Discord is a separate, optional
conversation (the bridge never mirrors the room). `acc swarms deploy` ends
with a pointer to `acc swarms room`, never the passphrase.

`acc create agent <name> [--model <provider/model>]` (acc ≥ 1.3.0) writes
`model = "openai/gpt-5.6-sol"` unless `--model` says otherwise (`openai/…` or
`anthropic/…`; anything else fails `model_invalid`). Imports (`--from`) keep the
source's model when it names one and fall back to the same default. Before
this the default was `af/kimi-k2.7`, which the hosted runtime cannot route: a
fresh project's first `acc swarms deploy` failed `SWARM_MODEL_UNSUPPORTED`
until `acc swarms model set` rewrote the project config.

`acc swarms logs` fails with `SWARM_LOGS_UNAVAILABLE` (retryable; the message
says whether the provider is rate limiting) instead of `Unexpected error.`
when the provider's log endpoint fails (API 2026-09-16). Never poll it faster
than once per second.

`acc swarms model set <provider/model>` (2026-09-14) sets the project's hosted
model server-side — `openai/<model>` or `anthropic/<model>`, or
`compat/<model> --base-url https://…` for any OpenAI-compatible endpoint.
Applied by the next `acc swarms deploy`. Since API 2026-09-18 (item C) a
project WITHOUT its own `OPENAI_API_KEY`/`ANTHROPIC_API_KEY` secret is wired
to the platform's inference proxy: every deploy mints a service-bound,
inference-only organization token for the runtime, asks the proxy's verdict
for the model BEFORE any spend, and revokes the token on stop, close and
delete. Pre-spend refusals: `SWARM_MODEL_DISABLED` (switched off under Org ›
Models), `SWARM_INFERENCE_BALANCE_LOW` (wallet), `SWARM_SUBSCRIPTION_INACTIVE`,
`SWARM_INFERENCE_UNAVAILABLE`, `SWARM_MODEL_UNSUPPORTED` (agents disagree on a
model or use an unsupported provider). `acc secrets set OPENAI_API_KEY` is now
the optional project override (direct provider call with that key);
`SWARM_MODEL_KEY_MISSING` only appears when such a key was deleted after the
config referenced it. Usage rows carry the runtime service id
(`GET /billing/credits/org/<org>/usage?serviceId=`).

`--swarm <name>` (1.5.0) on `agent export --remote`, `agent freeze|hydrate`,
`state read|history|verify`, `fork`, `mcp add --remote`, `models test` and
`tee attest` selects the deployed swarm when the project runs more than one;
without it the API resolves the single live runtime (stale rows of stopped
swarms no longer cause `CONFLICT`; when two are live the CONFLICT message
names them and says `--swarm`).

`acc run <swarm> --remote` (2026-09-14 output contract): the DEFAULT mode
prints only the answer text (`output.content`) followed by
`cost: $… (model $… + lease $…) · run <id>` — the informational per-run USD
(list-price tokens + the run's share of the lease $/h; never a wallet debit).
Event NDJSON and the raw result envelope (now with `usd_cost`,
`cost_breakdown`) appear only under `--json`; canonical AG-UI events under
`--ag-ui`.

`acc eval run <suite>` takes the suite NAME, not a path: it reads
`evals/suites/<suite>.toml` under the project (override with `--config <path>`).
Passing a path fails with `eval_suite_invalid` and the error now names the
directory suites live in.

`acc secrets set <NAME> --stdin --project <id>` stores a runtime secret for the
project (Infisical-backed; the value is read from the pipe, never from argv,
and never echoed). Byte handling: a single-line value loses exactly one
trailing newline (the one `echo` adds); a multi-line document is stored
byte-exact, final newline included. Multi-line runtime files such as the state
keyring depend on that final newline (fixed 2026-09-13; earlier builds shortened
every value by one byte).

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
