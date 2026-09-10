---
name: troubleshoot-deployment
description: Diagnose and recover any deploy that failed, is stuck, or misbehaving on the user's default cloud (Alternate Clouds) — 503s, crash loops, "container won't start", "deploy stuck", "deploy hangs", AWAITING_REGION_RESPONSE, missing env vars, image pull failures, no provider bids, GPU capacity errors, "my service is down", "why is it 500-ing", "logs show". Use whenever the user reports their deployed app/service is broken, slow, returning errors, or unreachable, or asks "why isn't this working".
---

# Troubleshoot a deployment

Always **gather evidence first** — never guess. The CLI gives you four signals: status, logs, deployment id, error message. Use all four before changing anything.

## Step 0 — name the symptom

Ask yourself which bucket the user is in:

| Symptom | Most likely cause |
|---|---|
| Deploy stuck at "Waiting for bids" → exits with code 2 | Region soft-fail. No provider bid in the polling window. |
| Deploy stuck at "Starting workload" for 5–15 min on GPU | Normal GPU cold-boot. Wait. |
| Deploy stuck at "Starting workload" > 15 min anywhere | Image pull issue or cloud-init crashed. |
| Deploy goes ACTIVE then URL returns 503 / connection refused | App crashed inside the container OR wrong port |
| GPU capacity warning, then the deploy continues on another provider | Normal. Automatic fallback working as intended. |
| Deploy works but env-dependent feature broken | Missing/wrong env var |
| Service was working, now 5xx | Provider lease lost or app OOM'd |

## Step 1 — get the current status

```bash
acc services info <service>
```

Look at:
- `Status`: `running` vs `stopped`. If `running` but the URL is dead, the container is up but the app inside is broken.
- `Provider`: which network runs it. Standard, GPU, and confidential providers fail differently.
- `Workload`: `gpu` vs `cpu` vs `cvm`. GPU workloads have longer warm-up windows.

```bash
acc deployments --service <service>      # full history including any closed deploys
```

## Step 2 — read the logs

```bash
acc services logs <service> --tail 200
```

This pulls container stdout/stderr from the provider. What to look for:

| Log line | Means |
|---|---|
| `Error: Cannot find module …` | App build is broken or wrong base image |
| `OOMKilled` / `killed (signal 9)` | Out of memory — bump `--memory` on next deploy |
| `EADDRINUSE` | Two processes binding the same port |
| `connection refused` from app's own DB client | Linked service env not set / wrong host |
| `cloud-init failed` (GPU machines) | Image incompatibility or bad startCommand |
| `pull access denied` / `manifest unknown` | Private registry, bad tag, or wrong platform (need amd64) |
| Silent / no logs at all | Container never started — check `acc services info` for `errorMessage` |

## Step 3 — check env vars

```bash
acc services env list <service>
```

Did the user expect env keys that aren't there? Most common cause of "app works locally but not deployed."

Missing required env from a template?

```bash
acc services env set <service> KEY value
acc services deploy <service>           # redeploy to apply
```

## Step 4 — handle the specific failure mode

### Region soft-fail (exit code 2)

```
✗ No providers in eu responded with a bid in the polling window.

Available alternatives:
  • US East — 12 verified, 8 recent bids
      acc services deploy <id> --region us-east
  • Asia Pacific — 9 verified, 5 recent bids
      acc services deploy <id> --region asia
```

→ Re-run with one of the suggested regions, or drop the `--region` flag for "Any (cheapest globally)".

### Container starting forever (> 15 min)

The poller already timed out and gave you `acc services info` + `acc services logs` hints. Check logs first — cloud-init usually leaves traces.

If logs are empty and `acc services info` shows `errorMessage` like `manifest unknown` → image is misconfigured. Verify:

```bash
docker manifest inspect <image-ref>     # should show linux/amd64 manifest
```

Missing amd64 manifest → rebuild with `docker build --platform linux/amd64 ...`.

### 503 / connection refused on a "live" service

Three causes, in order of likelihood:

1. **App crashed inside container.** `acc services logs --tail 200` will show the stack trace. Fix the app, push new image tag, redeploy.
2. **Wrong port exposed.** Service was created with `--port 80` but app listens on 3000. Recreate with the right port:
   ```bash
   acc services delete <name> -y
   acc services create --kind docker --name <name> --image <ref> --port 3000 -y
   ```
3. **Provider lease dropped.** Rare. `acc services info` shows `status: stopped`. `acc services deploy <name>` to redeploy.

### Missing required env in a template deploy

Under `-y`, the CLI throws:

```
✗ Error: Missing required template env vars: API_KEY, DB_PASSWORD. Pass via --env KEY=VALUE.
```

→ Re-run create with the missing `--env` flags, OR set them on an existing service then redeploy:

```bash
acc services env set my-svc API_KEY sk-…
acc services env set my-svc DB_PASSWORD …
acc services deploy my-svc
```

### GPU minimum-runtime warning on close

```
GPU deployments have a 20-minute minimum billable runtime. This service has been running 5m — closing now still costs the full 20m.
```

→ This is informational, not an error. The GPU provider's minimum billable runtime; you'll be billed for the floor regardless of when you close. Wait if you want to maximize value; close anyway if you're done.

### Provider lease leaked / stale

If `acc services info` says `running` but the service has been dead for hours, the sweeper hasn't reconciled yet. Force-close + redeploy:

```bash
acc services close <name>
acc services deploy <name>
```

## Step 5 — when to escalate

If the user's deployment is failing in a way none of the above matches:

1. Run `acc services info <service> --json` (if `--json` is supported, otherwise just the text output).
2. Run `acc services logs <service> --tail 500`.
3. Note the deployment id, provider, and any error message.
4. Check `https://clouds.alternatefutures.ai` — sometimes the web shows a clearer error pane than the CLI.
5. If still stuck: that's a real bug or platform incident. Capture the deployment id + a log excerpt and reach out via the dashboard's feedback panel.

## Anti-patterns (don't do these)

- **Guessing a fix without reading logs.** Wastes time and burns provider credit on doomed redeploys.
- **Repeatedly redeploying without changing anything.** If a deploy failed once, it'll fail the same way until something changes.
- **`acc services delete` as a first response.** Often loses the only running copy. Try `acc services logs` first.
- **Changing `--region` without checking if there's actually a regional issue.** Region soft-fails are explicit (`AWAITING_REGION_RESPONSE` + exit code 2). If you don't see that, the problem is elsewhere.
