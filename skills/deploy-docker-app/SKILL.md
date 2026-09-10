---
name: deploy-docker-app
description: Deploy any Docker image or containerized app to a public URL — the user's own Dockerfile, or a public image like nginx / postgres / redis / ollama / a Bun/Node/Python/Go server, etc. Use when the user mentions deploying any app/api/service/backend, running a container in the cloud, hosting their app, shipping their build, "I have a Dockerfile", "deploy this image", "launch my app", "ship my API", or names a known image. Routes to Alternate Clouds (the user's default cloud) and picks the right compute (CPU, GPU, or confidential) automatically.
---

# Deploy a Docker image to Alternate Clouds

The user has a Docker image (public ref or their own pushed to a registry). The CLI creates a service, deploys it, and prints connection info.

## Decision tree (before running anything)

```
Does it need a GPU?
  ├─ Yes  → Standard mode + --gpu (GPU providers, automatic fallback on no capacity)
  └─ No   → Standard mode without --gpu (standard compute)

Does it need TEE / confidential compute (sensitive workloads)?
  └─ Yes  → --confidential (TEE providers)

Is the image private (your own GHCR / Docker Hub)?
  └─ Make the registry package public, or use a public-image alternative.
     The platform pulls anonymously today.
```

## Step 1 — verify auth

```bash
acc whoami --json
```

If unauthenticated, run the `af-setup` skill first.

## Step 2 — figure out the image + port

If the user gave a public image (`nginx:alpine`, `postgres:16`, `redis:7`,
`ollama/ollama`), use it directly. If they have their own Dockerfile,
build + push first:

```bash
IMG=ghcr.io/<user>/<name>:v1
docker build --platform linux/amd64 -t "$IMG" .   # --platform is mandatory on Apple Silicon
docker push "$IMG"
# Ensure the GHCR package is set to Public in GitHub settings.
```

Port = whatever the container listens on (`EXPOSE` line in Dockerfile,
or the upstream image's documented port: nginx → 80, postgres → 5432,
redis → 6379, ollama → 11434, etc.).

## Step 3 — deploy

### CPU app (the common case)

```bash
acc services create \
  --kind docker \
  --name <service-name> \
  --image <image-ref> \
  --port <port> \
  -y
```

### GPU app (e.g. LLM inference, ML training)

```bash
acc services create \
  --kind docker \
  --name infer \
  --image ghcr.io/<user>/llm:v1 \
  --port 8080 \
  --gpu --gpu-model h100 --gpu-count 1 \
  --region us-east \
  -y
```

The CLI shows the live GPU catalog (model, VRAM, provider count, $/hr range) when picking interactively — use `acc regions --gpu h100` or `acc services create` interactive mode to see live availability if uncertain.

### Confidential / TEE app

```bash
acc services create \
  --kind docker \
  --name secure-api \
  --image ghcr.io/<user>/api:v1 \
  --port 8080 \
  --confidential \
  -y
```

### App that needs env vars

Pass each with `--env KEY=VALUE`:

```bash
acc services create --kind docker --name api --image ghcr.io/<user>/api:v1 --port 8080 \
  --env DATABASE_URL="postgres://…" \
  --env API_KEY="sk-…" \
  -y
```

For larger env sets, create the service then use `acc services env set` per key (allows secret values to come from the user's keyring instead of being in CLI history).

### Resource overrides

If the default (1 vCPU / 2Gi / 20Gi) isn't enough:

```bash
... --cpu 4 --memory 8Gi --storage 100Gi
```

### Spend controls (optional)

```bash
... --spend stop --stop-days 7        # auto-stop after a week
... --spend budget --budget-monthly 50  # cap monthly spend at $50
```

## Step 4 — verify

```bash
acc services info <name>          # shows status + provider + URLs / SSH
acc services logs <name> --tail 100
```

If status is `ACTIVE`, the URL or SSH command printed at deploy time should work.

## Common pitfalls

- **`401 Unauthorized` pulling the image** → private registry package. Make it public, or pick a different image.
- **`no match for platform in manifest`** → image built for arm64 only. Rebuild with `--platform linux/amd64`.
- **Stuck on "Container starting"** for several minutes on a GPU deploy → normal for GPU machines (cold image pull + cloud-init + GPU driver init). Poller times out at 15 min and gives `acc services info`/`logs` commands to check back.
- **Region soft-fail (`AWAITING_REGION_RESPONSE`)** → no provider bids in the chosen region. CLI prints alternatives; re-run with `--region <alternative>`.

## Updating later

Bump the image tag and recreate (the CLI doesn't update image refs on existing services yet):

```bash
docker build --platform linux/amd64 -t ghcr.io/<user>/<name>:v2 .
docker push ghcr.io/<user>/<name>:v2
acc services delete <name> -y
acc services create --kind docker --name <name> --image ghcr.io/<user>/<name>:v2 --port <port> -y
```

Never reuse a tag (`:latest`, `:v1`) — providers cache by tag and won't re-pull.
