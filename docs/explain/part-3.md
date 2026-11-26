# Part 3 explained — Kubernetes (k3d cluster "shop" + local registry)

## Why this part exists
Docker Compose (Parts 1-2) only runs on one machine and has no concept of "restart this container
automatically if it dies" or "add more copies when traffic increases" — a human has to do that.
Kubernetes manages containers for you: restarts crashed ones, moves them between machines, and
(via the HPA) scales them up/down automatically based on real load. We use **k3d**, which runs a
real lightweight Kubernetes (k3s) entirely inside Docker containers on your laptop — no cloud
account needed to learn the same commands we'll later run against AWS.

## File-by-file

### `scripts/local-k8s-up.sh`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/scripts/local-k8s-up.sh)

Step by step:
1. Creates a local Docker image registry (`k3d registry create`) — Kubernetes can't use the images
   already sitting in `docker images` directly; it needs them in a registry it can pull from, even
   a local one.
2. Creates the k3d cluster named `shop`: 1 server node + 2 agent nodes (all Docker containers
   acting as "fake machines"), with Traefik disabled (`--disable=traefik` — that's k3s's built-in
   ingress controller; we use our own nginx instead, see `CLAUDE.md`'s deviation note about
   ingress-nginx's retirement), and port `${LB_PORT:-8888}` on your laptop mapped to port 80 on the
   cluster's load balancer (`-p "${LB_PORT}:80@loadbalancer"`).
   > ⚠️ Originally this used port 8080, but Kareem already has an unrelated Jenkins instance
   > running on `localhost:8080` on his machine (not ours — our own Jenkins in Part 5 uses 8090,
   > see `jenkins/run-jenkins.sh`). To avoid any clash with it, the cluster's load balancer now
   > defaults to **8888** (override with `LB_PORT=<port> ./scripts/local-k8s-up.sh`).
3. Rebuilds the same Part 1 Docker images, then `k3d image import`s them straight into the
   cluster's containerd — no registry push/pull needed for local work.
4. Creates the `shop` namespace and a `db-credentials` Secret holding the Postgres password (read
   from `docker/.env`, never hardcoded).
5. `kubectl apply -k k8s/overlays/local` — this is **Kustomize**: `k8s/base/` holds the
   environment-independent YAML, and `k8s/overlays/local/` patches it for this specific
   environment (adds the Postgres StatefulSet, caps the HPA's max replicas lower for a laptop).
   The same `base/` gets a *different* overlay (`overlays/aws/`) for the real cluster later —
   one source of truth, environment-specific tweaks layered on top.

### `k8s/base/web.yaml` (same pattern for `search.yaml`, `payment.yaml`)
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/k8s/base/web.yaml)

A Deployment + Service pair:
- **No `replicas:` field** — on purpose. The HorizontalPodAutoscaler (next file) owns the replica
  count; if we set `replicas: 1` here, every `kubectl apply` would silently reset the scaled-up
  count back to 1, fighting the HPA.
- `strategy.rollingUpdate: { maxSurge: 1, maxUnavailable: 0 }` — during an update, Kubernetes
  always starts a new pod *before* removing an old one, and never drops below the desired count.
  This is the first of the 5 rollback-safety layers described in `CLAUDE.md` (Part 6).
- `readinessProbe` (hits `/ready`) controls whether a pod receives traffic; `livenessProbe` (hits
  `/health`) controls whether Kubernetes restarts the container. Different purposes: a pod can be
  "alive" but not "ready" (e.g. still warming up or temporarily can't reach the database).
- `resources.requests` (`100m` CPU = 0.1 of a core) is what the HPA's percentage is measured
  against — "60% utilization" means 60% of the *requested* 100m, not of a whole CPU core.
- `securityContext: runAsNonRoot, allowPrivilegeEscalation: false, capabilities: drop: [ALL]` —
  the same non-root principle from Part 1's Dockerfiles, enforced again at the Kubernetes level so
  even a misconfigured image can't run as root inside the cluster.

### `k8s/base/hpa.yaml`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/k8s/base/hpa.yaml)

Two `HorizontalPodAutoscaler` objects (one per scalable service: `web`, `search`). Each watches CPU
usage via `metrics-server` (bundled with k3s) and keeps replica count between `minReplicas: 2` and
`maxReplicas: 6`, targeting 60% average CPU utilization. `scaleDown.stabilizationWindowSeconds: 120`
(shortened from Kubernetes's default 300s) means it waits 2 minutes of sustained low usage before
removing a pod — long enough to avoid flapping, short enough to actually see scale-down in a demo.

### `k8s/overlays/local/kustomization.yaml`
Patches the base: adds the local-only Postgres StatefulSet (`postgres.yaml`), caps HPA
`maxReplicas` lower (laptop CPU is limited), and points images at the locally-imported
`local/ecom-*:dev` tags instead of a registry.

## How to demo this part
```bash
cd ~/automated-e-commerce-deployment-platform
bash scripts/local-k8s-up.sh
```
Takes a few minutes the first time (downloading the k3s images). At the end:
```bash
kubectl -n shop get pods,svc,hpa
curl -s http://localhost:8888/api/search/products | jq length   # should print 12
```
Then open `http://localhost:8888` in a browser — same storefront, now running on Kubernetes.

## 5 questions an instructor might ask

**1. Why k3d instead of minikube or Docker Desktop's built-in Kubernetes?**
k3d runs the real, lightweight k3s distribution (used in production for edge/IoT and small
clusters) inside plain Docker containers — fast to start, low resource overhead, and the exact
same k3s we use on the real AWS EC2 nodes in Part 7, so commands and behavior transfer directly.

**2. Why remove the `replicas:` field instead of just setting it once?**
Because `kubectl apply` is declarative — it tries to make the live state match the YAML file
exactly. If the YAML said `replicas: 2` and the HPA had scaled up to 5, the next `apply` would
scale it back down to 2, undoing the HPA's work. Omitting it lets the HPA be the sole owner of that
field.

**3. What's the difference between the readiness and liveness probes?**
Liveness failing means "restart this container" (it's stuck/crashed). Readiness failing means
"don't send it traffic yet, but don't restart it" (e.g. still connecting to the database on
startup) — a pod can fail readiness without ever being killed.

**4. Why does the HPA need `resources.requests` set on the container?**
CPU/memory utilization percentages are only meaningful relative to something — the HPA computes
"current usage ÷ requested amount" to get a percentage, so without a request value there's nothing
to divide by and the HPA can't function.

**5. How is Kustomize different from just having separate YAML files per environment?**
Kustomize keeps one base set of manifests and layers small, explicit patches per environment
(`overlays/local`, `overlays/aws`) — a change to the shared logic (like a new env var on `web`)
is written once in `base/` and automatically applies everywhere, instead of being copy-pasted into
every environment's full YAML and risking drift between them.
