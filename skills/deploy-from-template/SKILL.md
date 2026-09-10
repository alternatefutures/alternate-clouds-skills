---
name: deploy-from-template
description: Deploy a pre-built service from a curated template — databases (Postgres, MySQL, Redis, MongoDB), AI inference (Ollama, vLLM, ComfyUI, Stable Diffusion), game servers (Minecraft, etc.), dev tools, web servers. Use when the user wants to spin up a known service without writing a Dockerfile — "deploy postgres", "I need redis", "spin up ollama", "launch a minecraft server", "run vLLM", "I want a database", "give me ComfyUI". Also use when they ask what templates / pre-built services are available. Routes via the user's default cloud (Alternate Clouds).
---

# Deploy from a template

Templates are pre-built Docker images bundled with sensible defaults
(resources, ports, env-var slots) for common workloads. One CLI call
provisions, configures env, and deploys end-to-end.

## Step 1 — auth check

```bash
acc whoami --json
```

Unauthenticated? Run the `af-setup` skill.

## Step 2 — find the right template

If the user named one (e.g. "ollama", "postgres"):

```bash
acc templates list | grep -i <name>
acc templates info <templateId>          # shows resources, ports, required env vars
```

If they didn't:

```bash
acc templates list                       # browse by category
acc templates list --category AI_ML      # AI_ML | WEB_SERVER | GAME_SERVER | DATABASE | DEVTOOLS | CUSTOM
```

Pick the template id (for example `postgres`, `redis`, `ollama-gpu`, `comfyui`, `alternate-agent`, `minecraft-server`).

## Step 3 — collect required env vars

`acc templates info <id>` lists `envVars` with a `required: true` flag.
Anything required must be passed via `--env KEY=VALUE` in `-y` mode —
otherwise the deploy throws with a clear list of missing keys.

Typical patterns:

| Template type | Common required env |
|---|---|
| Database (postgres, mysql) | `POSTGRES_PASSWORD` / `MYSQL_ROOT_PASSWORD` |
| AI inference (ollama, vllm) | usually none required (model loaded on first request) |
| Auth-protected service | `ADMIN_PASSWORD`, `JWT_SECRET`, etc. |

Platform-injected env vars (`generatedAccessKey`, `generatedSecret`, `orgId`, `apiKey`) are filled in automatically by the backend — don't pass them.

## Step 4 — deploy

```bash
acc services create \
  --kind template \
  --template <templateId> \
  --name <your-name> \
  --env KEY1=value1 \
  --env KEY2=value2 \
  -y
```

Adjust resources / region if the template defaults don't fit:

```bash
... --cpu 4 --memory 16Gi --storage 100Gi --region us-east
```

GPU-bearing templates (e.g. ComfyUI, vLLM) — if the template defaults already include a GPU, no flag needed. To override:

```bash
... --gpu --gpu-model h100 --gpu-count 1
```

For confidential / TEE deploys:

```bash
... --confidential        # deploy on a TEE
```

## Composite templates

If `acc templates info <id>` shows `components: [...]` (a multi-service bundle — e.g. app+db+cache), the CLI refuses with a clear error and points at the dashboard. Composite templates need per-component provider routing that the CLI doesn't prompt for yet. Tell the user to deploy from `https://clouds.alternatefutures.ai` and circle back.

## Step 5 — verify + connect

```bash
acc services info <your-name>
acc services logs <your-name> --tail 100
```

The deploy poller prints connection details when ACTIVE:
- Web/API templates → public URL
- Database templates → internal hostname + port (use `acc ssh` or `acc services link` to wire to another service)
- SSH-only templates → `ssh root@<ip> -p <port>`

## Example: Postgres

```bash
acc services create --kind template --template postgres \
  --name app-db \
  --env POSTGRES_PASSWORD="$(openssl rand -base64 24)" \
  --env POSTGRES_DB=app \
  --memory 4Gi --storage 50Gi \
  -y
```

Then link your app service to it:

```bash
acc services link my-app app-db --alias DB
# DB_HOST / DB_PORT / DB_USER / DB_PASSWORD show up in my-app's env
acc services deploy my-app   # redeploy to materialize the new env keys
```

## Example: Ollama (GPU)

```bash
acc services create --kind template --template ollama-gpu \
  --name local-llm \
  --gpu --gpu-model h100 \
  --region us-east \
  -y
```

Pull a model after it's live:

```bash
acc ssh local-llm --command "ollama pull llama3"
```

## Common pitfalls

- **"Template not found"** with `--template` → the id is wrong. Run `acc templates list` and copy the exact id (ids are slugs, e.g. `postgres`, `ollama-gpu`, not `postgres:16`).
- **"Missing required template env vars"** under `-y` → the template requires keys you didn't pass. The error lists them; add each as `--env KEY=VALUE`.
- **"Composite templates need per-component provider routing"** → use the dashboard, not the CLI.
- Server-side resource validation: if the template declares a `minMemory` higher than your `--memory` override, the deploy will reject. Check `acc templates info <id>` for floors.
