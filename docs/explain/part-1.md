# Part 1 explained — Docker: the 4 services + database

## Why this part exists
Before Kubernetes, before Jenkins, before AWS — we need the application itself running
*somewhere*, reproducibly. Docker Compose is the simplest "somewhere": one file describes
every container, their images, and how they reach each other, and `docker compose up` brings
the whole stack up identically on your laptop, a teammate's laptop, or inside Jenkins later.

## File-by-file

### `docker/docker-compose.yml`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/docker/docker-compose.yml)

Defines 5 services:
- `db` — builds from `app/db` (Postgres 16 with the schema+seed data baked into the image itself,
  so the same image works identically in Jenkins/CI where there's no host folder to bind-mount).
  Has a `healthcheck` using `pg_isready` — nothing else starts until Postgres actually accepts
  connections, not just "the container exists".
- `search` and `payment` — both depend on `db` being healthy (`depends_on: db: condition:
  service_healthy`), and both get `DATABASE_URL` injected via a YAML anchor (`&db-url` / `*db-url`)
  so the connection string is written once and reused, not copy-pasted three times.
- `web` — depends on both `search` and `payment` being healthy, and knows how to reach them via
  their service names (`http://search:8081`, `http://payment:8082`) — Docker Compose's built-in DNS
  resolves a service name to that container's IP automatically.
- `nginx` — the **only** service that publishes a port to your machine (`${NGINX_PORT:-80}:8080`).
  Every other service is only reachable from inside the Docker network — that's deliberate: the
  outside world (your browser) should only ever talk to nginx, the same pattern we'll use in
  Kubernetes in Part 3.

### `app/web/Dockerfile` (and `search`, `payment` — nearly identical)
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/app/web/Dockerfile)

A two-stage build:
- **Stage 1 (`builder`)**: installs Python dependencies into `/install` using `pip install
  --prefix=/install`. This stage's only job is to produce installed packages — it's thrown away
  after.
- **Stage 2 (runtime)**: starts fresh from a clean `python:3.12-slim`, copies *only* the installed
  packages from stage 1 and the app code — none of pip's build cache or compiler toolchain ends up
  in the final image. This is why it's called "multi-stage": smaller, cleaner final image.
- `useradd --uid 10001 appuser` + `USER 10001` — the container runs as a non-root user. If someone
  ever broke into the app through a vulnerability, they'd have no root privileges inside the
  container.
- `HEALTHCHECK` — Docker itself polls `/health` every 15s; this is what `docker compose ps` uses to
  show "healthy", and what Compose's `depends_on: condition: service_healthy` waits for.
- The comment about `--workers 1 --threads 8` explains a real constraint: the `prometheus_client`
  Python library (used for the `/metrics` endpoint, Part 4) keeps its counters in per-process
  memory. Multiple worker *processes* would each have their own counters and give wrong numbers.
  One process with multiple *threads* avoids that, and we scale by running more container
  replicas (pods) instead — which is exactly what Part 3's Kubernetes HPA does.

### `app/db/init.sql`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/app/db/init.sql)

Plain SQL: creates the tables (`products`, `orders`, etc.) and inserts 12 demo products. Postgres's
official image automatically runs any `.sql` file placed in `/docker-entrypoint-initdb.d/` the
*first* time the container starts with an empty data directory — that's how this seed data gets
in without any extra scripting.

### `app/web/app.py` (and `search/app.py`, `payment/app.py`)
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/app/web/app.py)

This is the **provided application code** (per `CLAUDE.md`, we don't rewrite it — only fix bugs
that block a DevOps task). It's a small Flask app with `/health` (liveness), `/ready` (readiness —
can it actually reach its dependencies), and `/metrics` (Prometheus format) endpoints, plus the
actual shop logic (serving products, placing orders). `payment/app.py` includes a deliberately
fake payment gateway with a specific test card number that always gets declined — useful later for
demoing error handling and rollback, not a real payment processor.

### `scripts/compose-smoke-test.sh`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/scripts/compose-smoke-test.sh)

What already passed 7/7 on your machine. Brings the stack up under an isolated project name
(`shop-test`, so it never collides with your normal `docker compose up`), then runs a `curl`
container **inside the same Docker network** (not from your host) to hit each endpoint — this
matters because it proves the containers can reach *each other*, which is the thing that actually
breaks in real deployments (host-only testing can hide network issues). It checks: both health
endpoints, the product list, placing a real order, and a declined test-card payment.

## How to demo this part
```bash
cd ~/automated-e-commerce-deployment-platform
docker compose -f docker/docker-compose.yml up -d --build
docker compose -f docker/docker-compose.yml ps
```
Open `http://localhost` in a browser — storefront should load with 12 products.
`docker compose -f docker/docker-compose.yml down` to stop.

## 5 questions an instructor might ask

**1. Why multi-stage Docker builds instead of one `FROM` with everything?**
Smaller final image (no build tools, no pip cache) and a smaller attack surface — nothing in the
shipped image can be used to rebuild or modify the app.

**2. Why does only nginx publish a port?**
Defense in depth: the app services have no reason to be reachable directly from outside, so they
simply aren't. All external traffic is forced through one audited, rate-limited entry point.

**3. Why bake `init.sql` into the `db` image instead of mounting it as a volume?**
A baked-in image works identically everywhere — your laptop, a teammate's laptop, Jenkins (which
has no access to your host's file paths), or later pushed to a registry for Kubernetes to pull.
A bind-mount only works on the machine that has that exact file path.

**4. Why gunicorn with 1 worker + 8 threads instead of the usual "workers = 2× CPU cores" advice?**
Because of the `prometheus_client` per-process metrics constraint explained above — scaling here
happens horizontally (more containers/pods), not by adding worker processes inside one container.

**5. How do you know the services can actually talk to each other, not just that each one starts?**
`compose-smoke-test.sh` runs its checks from *inside* the Docker network via a separate `curl`
container, and includes a full purchase flow (search → add to cart → pay) — that proves the
inter-service HTTP calls work, not just that each container's own healthcheck passes.
