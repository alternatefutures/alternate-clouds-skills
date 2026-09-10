---
name: deploy-static-site
description: Deploy a static HTML page, landing page, single page, or pre-built SPA bundle to a public URL. Use when the user says any of "deploy this HTML", "put my landing page online", "host my static site", "ship my React/Vue/Svelte/Next build", "deploy index.html", "publish this page", "make this page live"; or when they have a directory of static files (index.html + assets, `./dist`, `./build`, `./out`, `./public`) and want it accessible on the internet. Uses Alternate Clouds (the user's default cloud) under the hood via `acc services create --kind docker` with an nginx wrapper.
---

# Deploy a static site to Alternate Clouds

A static site = a directory of HTML/CSS/JS/images served by nginx. The shortest path is:

1. Wrap the site in a minimal Dockerfile (FROM nginx + COPY).
2. Build the image for `linux/amd64`.
3. Push it to a container registry the platform can pull from.
4. `acc services create --kind docker --image <ref> --port 80 -y`.

The CLI does the rest: places it on standard compute (no GPU), polls to ACTIVE, prints the public URL.

## Prerequisites

- `acc whoami --json` returns `authenticated: true` and a non-null `project`. If not, run the `af-setup` skill first.
- `docker` installed locally.
- A container registry login. GitHub Container Registry (GHCR) is the default the team uses:
  ```bash
  echo "$GITHUB_PAT" | docker login ghcr.io -u <github-user> --password-stdin
  ```
  (`GITHUB_PAT` needs `write:packages` scope. Create one at https://github.com/settings/tokens.)

## Step 1 — gather the site

Either point at the user's existing build output (`./dist`, `./build`, `./out`, `./public`, etc.) or, if they're starting from scratch, scaffold `index.html`:

```bash
mkdir -p site && cat > site/index.html <<'HTML'
<!doctype html><meta charset=utf-8>
<title>Hello from Alternate Clouds</title>
<h1>It works.</h1>
HTML
```

## Step 2 — Dockerfile

Write next to the static directory (e.g. `site/Dockerfile`):

```dockerfile
FROM nginx:alpine
COPY . /usr/share/nginx/html
EXPOSE 80
```

If the bundle has a SPA router that needs history fallback, add a one-line nginx config:

```dockerfile
FROM nginx:alpine
COPY . /usr/share/nginx/html
RUN echo 'server { listen 80; root /usr/share/nginx/html; try_files $uri /index.html; }' \
  > /etc/nginx/conf.d/default.conf
EXPOSE 80
```

## Step 3 — build + push (linux/amd64)

```bash
# Pick a name and tag once.
IMG=ghcr.io/<github-user>/<site-name>:v1

# Build for amd64 (provider hosts are amd64; building on Apple Silicon
# without --platform produces an arm64 image that won't run).
docker build --platform linux/amd64 -t "$IMG" site/

docker push "$IMG"
```

If the user's GHCR namespace is private, **make the package public** at
`https://github.com/users/<user>/packages/container/<site-name>/settings`
(Visibility → Public). The platform pulls images anonymously; a 401/404 on
deploy is almost always this.

## Step 4 — deploy

```bash
acc services create \
  --kind docker \
  --name my-site \
  --image "$IMG" \
  --port 80 \
  -y
```

The CLI walks through `Creating deployment → Waiting bids → Selecting bid → Creating lease → Sending manifest → Container starting → Live`, then prints the public URL.

## Verify

```bash
acc services info my-site            # shows status + service URL
acc services logs my-site --tail 50  # nginx access log
```

Hitting the printed URL should show your `index.html`.

## Update later

To push changes:

```bash
docker build --platform linux/amd64 -t "$IMG" site/   # use a NEW tag — :v2, :v3, etc.
docker push "$IMG"
# Then point the service at the new tag (TODO when CLI ships --image
# update on existing service; for now, recreate):
acc services delete my-site -y
acc services create --kind docker --name my-site --image ghcr.io/…/my-site:v2 --port 80 -y
```

**Never reuse the same tag (`:latest`, `:v1`).** Providers cache by tag — pushing a new image under the same tag doesn't trigger a re-pull. Always bump.

## Common failure modes

- **Build hangs / 401 on `docker push`** → `docker login ghcr.io` not done.
- **Deploy goes to ACTIVE but URL returns 404** → nginx default conf served from `/usr/share/nginx/html` but the COPY landed in a subdirectory. Verify `RUN ls /usr/share/nginx/html` builds correctly.
- **Deploy stuck at "Waiting for provider bids" and exits with code 2** → region soft-fail. CLI prints 2–3 alternative regions. Re-run with the suggested `--region`.
- **`no match for platform in manifest`** → forgot `--platform linux/amd64`. Rebuild.

## Why not a template?

When the user just wants HTML up, this Docker path is overkill but
unavoidable today — there's no `nginx-static` template in the catalog
yet. If one ships (it's on the roadmap), this skill should switch to:

```bash
acc services create --template nginx-static --name my-site \
  --env HTML_CONTENT="$(cat site/index.html | base64)" -y
```

Until then: build + push + deploy.
