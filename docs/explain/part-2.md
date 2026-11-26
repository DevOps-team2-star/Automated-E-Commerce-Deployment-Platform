# Part 2 explained — Nginx: one entry point, load balancing, rate limiting

## Why this part exists
Part 1 already put nginx in front of the other services, but didn't prove *why* that matters.
Part 2 demonstrates the three jobs a reverse proxy actually does: route different URL paths to
different backend services, spread traffic across multiple copies of a service, and protect a
sensitive endpoint (payment) from being hammered.

## File-by-file

### `nginx/default.conf`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/nginx/default.conf)

- `upstream web_up { server web:8080; keepalive 16; }` (and one each for `search_up`, `payment_up`)
  — a named pool of backend servers. Right now each pool has one entry, but Docker Compose/K8s DNS
  resolves `search` to *whichever* container(s) answer that name, so scaling `search` to 3 replicas
  makes nginx load-balance across all 3 automatically, with zero config change.
- `location / { proxy_pass http://web_up; }` — anything that isn't matched by a more specific rule
  goes to the storefront.
- `location /api/search/ { proxy_pass http://search_up/; }` — note the trailing slash on
  `proxy_pass`: that's what strips the `/api/search/` prefix before forwarding, so the search
  service itself never needs to know it's mounted under that path.
- `location /api/payment/ { limit_req zone=payment_limit burst=20 nodelay; proxy_pass ...; }` — this
  is the rate limit. `limit_req_zone` (defined above, 10 requests/second per client IP, tracked in
  a 10MB shared memory zone) caps how fast one IP can hit the payment API; `burst=20` allows short
  spikes; anything beyond that gets an immediate HTTP 429 (`limit_req_status 429`).
- `location = /healthz` — a trivial `return 200 "ok"` used by Docker's healthcheck, Kubernetes
  probes later, and the AWS load balancer health check even later — same config file, three
  different consumers.
- `location = /nginx_status { stub_status; allow 127.0.0.1; allow 10.0.0.0/8; ... }` — exposes
  nginx's own connection counters for Prometheus to scrape in Part 4, restricted to private
  networks only (not reachable from the public internet).

### `scripts/nginx-demo.sh`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/scripts/nginx-demo.sh)

Three demo sections, each proving one of the three jobs above:
1. **Routing** — curls `/`, `/api/search/products`, `/api/payment/orders`, `/healthz` and prints
   the HTTP status of each, proving the path-based routing works.
2. **Load balancing** — scales `search` to 3 containers (`docker compose up -d --scale search=3`),
   restarts nginx so it re-resolves the DNS name to all 3 IPs, fires 30 requests, then greps
   nginx's own access log for the `upstream=<ip>:8081` field to show requests were actually spread
   across different container IPs — not just "it didn't error".
3. **Rate limiting** — fires 60 concurrent requests at the payment endpoint and counts how many got
   HTTP 200 vs HTTP 429, proving the `limit_req` rule actually rejects excess traffic instead of
   just existing in a config file nobody tested.

## How to demo this part
Your nginx is on port 8081 (since 80 was taken), so export that before running the script:
```bash
cd ~/automated-e-commerce-deployment-platform
export NGINX_PORT=8081
bash scripts/nginx-demo.sh
```

## 5 questions an instructor might ask

**1. Why use nginx's own `upstream` blocks instead of just pointing `proxy_pass` straight at the
service name?**
`upstream` blocks give control over connection pooling (`keepalive 16` reuses TCP connections to
the backend instead of opening a new one per request) and are the standard place to add
load-balancing algorithms, retries, and health checks if needed later.

**2. Why rate-limit only the payment endpoint and not search or the storefront?**
Payment is the most sensitive and most expensive operation (it touches money and triggers writes),
so it's the endpoint most worth protecting from abuse or accidental retry storms. Search and the
storefront are read-mostly and cheap by comparison.

**3. How does nginx "load balance" without any special load-balancer software?**
Nginx resolves the backend hostname (`search`) via DNS at the interval it's configured to, and
Docker Compose's/Kubernetes' built-in DNS returns one IP per healthy replica behind that name —
nginx then round-robins across whichever IPs come back. The "load balancer" is really just
DNS-returns-multiple-IPs plus nginx's default round-robin upstream behavior.

**4. What does `burst=20 nodelay` actually mean?**
The rate limit allows 10 requests/second steady-state; `burst=20` lets up to 20 requests queue up
beyond that before any are rejected, and `nodelay` means queued requests are processed immediately
rather than artificially spaced out — so legitimate short spikes aren't punished, but sustained
abuse still gets capped.

**5. Why is the exact same `nginx/default.conf` reused in Kubernetes later instead of writing a
separate config for each environment?**
One config to maintain and test, used identically everywhere (compose locally, a Kubernetes
ConfigMap on the cluster) — the same reasoning as baking `init.sql` into the db image in Part 1:
consistency between environments beats environment-specific configs that can drift apart.
