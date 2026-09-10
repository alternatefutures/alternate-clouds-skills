---
name: deploy-server
description: Spin up a raw VM the user can SSH into — no app, no Dockerfile, just an OS to log into. Use when the user asks for "a fresh server", "an Ubuntu box", "a VM", "a sandbox to mess around in", "compute for experimentation", "I need a machine", "SSH server", "root access to a server", "a GPU box for training", or needs arbitrary tooling installed on a clean machine. Routes via the user's default cloud (Alternate Clouds).
---

# Deploy a raw VM you can SSH into

This is the empty-machine path: no Docker image to push, no template,
no app. Pick an OS, pick resources, get a public IP + SSH command.

Under the hood the orchestrator pulls a Docker base image (`ubuntu:24.04`
etc.) and runs `sleep infinity` so the container stays up for SSH.

## Step 1 — auth check

```bash
acc whoami --json
```

If not authenticated, run the `af-setup` skill.

## Step 2 — pick OS + resources

The CLI's `--os` flag takes any Docker image; the picker offers four common choices:

| OS | `--os` value |
|---|---|
| Ubuntu 24.04 (default) | `ubuntu:24.04` |
| Ubuntu 22.04 | `ubuntu:22.04` |
| Debian 12 | `debian:12` |
| Alpine 3.20 | `alpine:3.20` |

Anything else: pass a full image ref (e.g. `nvidia/cuda:12.2.0-base-ubuntu22.04` for a CUDA-ready box).

## Step 3 — deploy

### CPU-only Ubuntu box

```bash
acc services create \
  --kind server \
  --name dev-box \
  --os ubuntu:24.04 \
  --cpu 2 --memory 4Gi --storage 50Gi \
  -y
```

### GPU box (e.g. for training / inference experiments)

```bash
acc services create \
  --kind server \
  --name gpu-box \
  --os nvidia/cuda:12.2.0-base-ubuntu22.04 \
  --gpu --gpu-model h100 --gpu-count 1 \
  --region us-east \
  -y
```

GPU boxes go to GPU-capable providers and fall back automatically on `NO_CAPACITY`; CPU-only boxes go to standard compute.

### With budget cap

```bash
... --spend stop --stop-days 7        # auto-stop after a week
... --spend budget --budget-monthly 30   # cap monthly spend
```

### Break-glass SSH key (recommended for GPU / long-running boxes)

Add your own SSH public key at deploy time so you keep **direct** access to the
box even if the platform's managed shell/heartbeat channel ever goes down:

```bash
acc services create --kind server --name gpu-box \
  --os nvidia/cuda:12.2.0-base-ubuntu22.04 --gpu --gpu-model h100 \
  --ssh-key-file ~/.ssh/id_ed25519.pub \
  -y
# or paste the key inline:
#   --ssh-key "ssh-ed25519 AAAA… you@host"
```

The key is baked into the VM's `authorized_keys` (root + `ubuntu`) and replayed
on resume. **GPU (raw server) boxes only**; ignored for container and confidential deploys. Reachability
depends on the provider allowing inbound `:22` from your source IP (residential
generally works; some datacenter ranges are filtered). This is a safety net, not
a replacement for `acc ssh <name>`.

## Step 4 — SSH in

After the deploy polls to ACTIVE, the CLI prints the SSH command directly:

```
✅ Deployment is live!
Provider: <network>
GPU:      H100
Region:   us-east
SSH:      ssh root@1.2.3.4 -p 22
```

Or:

```bash
acc ssh dev-box                   # CLI-mediated WebSocket shell (works on every provider)
acc ssh dev-box --command /bin/sh # specify shell
```

## Persistent storage

The container's filesystem is **ephemeral** — anything you install in
`/root` survives reboots within the same lease but not across redeploys.
For persistent data, pass `--storage <NGi>` (creates a persistent volume
attached at the platform's default mount point), or wire to a separate
storage service.

## Common pitfalls

- **GPU box stuck at "Starting workload" for 5+ minutes** → normal. GPU machine cold-boot + cloud-init + GPU driver init routinely takes 5–10 min. The poller's 15-minute timeout is sized for this.
- **`ssh: Connection refused`** → the SSH daemon takes a few extra seconds after the deploy says ACTIVE. Wait 15s and retry, or use `acc ssh <name>` which uses the platform's WebSocket shell (no port-22 dependency).
- **No `--os` flag with `-y`** → defaults to `ubuntu:24.04`. Matches the interactive picker's first choice.
- **`Service name … already exists`** → pick a different `--name` or `acc services delete <name> -y` first.

## Tear down

```bash
acc services close dev-box    # stop the deployment but keep the service record (resumable on next deploy)
acc services delete dev-box   # remove everything
```

For GPU machines, billing has a 20-minute minimum runtime; `acc services close`
warns when you're inside the floor so you know you'll still be billed for the
remainder.
