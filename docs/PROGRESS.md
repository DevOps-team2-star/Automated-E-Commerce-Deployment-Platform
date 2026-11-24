# Build progress

Each part is built on its own branch (`feat/part-N-...`) and merged to `main` through a pull request.

| Part | Branch | Status |
|---|---|---|
| 0 Setup + repo | feat/part-0-setup | built |
| 1 Docker | feat/part-1-docker | |
| 2 Nginx | feat/part-2-nginx | |
| 3 Kubernetes + HPA | feat/part-3-kubernetes | |
| 4 Monitoring | feat/part-4-monitoring | |
| 5 Jenkins CI/CD | feat/part-5-jenkins | |
| 6 Rollback | feat/part-6-rollback | |
| 7 Terraform | feat/part-7-terraform | |
| 8 Ansible | feat/part-8-ansible | |
| 9 AWS demo | feat/part-9-demo | |

## Deviations from docs/PLAN.md

- **No ingress-nginx.** The Kubernetes community retired the ingress-nginx controller in March 2026
  (no more releases or security fixes). Kubernetes instead runs the same Nginx reverse proxy as docker
  compose (`nginx/`), as a Deployment + Service. The ALB on AWS targets its NodePort 30080. This keeps
  deliverable 6 (Nginx) and removes an unmaintained component.

## Part 0 - Setup + repo

- Added the provided application (`app/`), `.gitignore`, `CLAUDE.md`, the plan and prompts in `docs/`.
- `scripts/install-tools.sh` installs kubectl, k3d, helm, kustomize, terraform, ansible (+ kubernetes
  python lib), aws cli v2, hey and hadolint in WSL2 Ubuntu. `scripts/check-tools.sh` verifies them.
- Manual steps (Kareem): Docker Desktop with WSL integration for Ubuntu; Docker Hub account + access
  token; AWS IAM user + `aws configure`; AWS Budget alert ($10).

## Part 1 - Docker

- `app/{web,search,payment}/Dockerfile`: multi-stage (`python:3.12-slim`), dependencies installed in a
  builder stage, runtime runs as UID 10001, `HEALTHCHECK` on `/health`, `APP_VERSION` build arg.
- Gunicorn runs **1 worker + 8 threads**: `prometheus_client` keeps metrics per process, so several
  workers would give inconsistent counters. Scaling is done with pods (HPA), not workers.
- `docker/docker-compose.yml`: db (Postgres 16 + init.sql + named volume + `pg_isready` healthcheck),
  search, payment, web; `depends_on: condition: service_healthy`; images named
  `${REGISTRY}/ecom-<svc>:${TAG}`; password from `docker/.env` (git-ignored, see `.env.example`).
- Run: `cp docker/.env.example docker/.env && docker compose -f docker/docker-compose.yml up -d --build`,
  open http://localhost:8080.
- Verify: `docker compose -f docker/docker-compose.yml ps` (all healthy),
  `docker compose -f docker/docker-compose.yml exec search whoami` -> `appuser`, `docker images | grep ecom`.

## Part 2 - Nginx reverse proxy

- `nginx/default.conf`: upstreams `web`, `search`, `payment`; routes `/` -> web, `/api/search/` and
  `/api/payment/` (prefix stripped by the trailing slash in `proxy_pass`), `/healthz` (for probes and the
  ALB), `/nginx_status` (stub_status, private networks only), custom `50x.html`. Forwarded headers,
  timeouts, retry on another upstream for 502/503, gzip, security headers, rate limit 10 r/s burst 20 on
  payment (returns 429).
- Image `nginxinc/nginx-unprivileged:stable-alpine` (non-root, port 8080). In compose it is the only
  service publishing a port (`NGINX_PORT`, default 80); web no longer publishes 8080.
- The same `default.conf` is reused unchanged in Kubernetes (Part 3).
- Run: `docker compose -f docker/docker-compose.yml up -d --build`, open http://localhost.
- `app/db/Dockerfile` and `nginx/Dockerfile` bake `init.sql` and `default.conf` into images instead of
  bind-mounting them. Jenkins drives the host Docker through its socket, where bind-mount paths from the
  Jenkins workspace would not exist, so baked images make the same compose file work in CI.
- Verify: `./scripts/compose-smoke-test.sh` (separate project `shop-test` on port 18080; requests sent from
  a curl container inside the stack network: routes + a purchase + a declined card),
  `./scripts/nginx-demo.sh` (routing table, spread over 3 search replicas, 429s from the rate limit).

## Part 3 - Kubernetes with auto-scaling

- `k8s/base`: namespace `shop`; Deployments + Services for web, search, payment (probes on `/ready` and
  `/health`, requests/limits, non-root, `maxUnavailable: 0`, `revisionHistoryLimit: 5`); `nginx`
  Deployment (same `default.conf` via a generated ConfigMap, plus `nginx-prometheus-exporter` sidecar)
  and Service (LoadBalancer :80, nodePort 30080); HPAs for web and search (60% CPU, 2-6 pods, 120 s
  scale-down window); PodDisruptionBudgets.
- web and search Deployments have no `replicas:` field: the HPA owns it, so a `kubectl apply` doesn't
  reset a scaled-out deployment.
- `k8s/overlays/local`: Postgres StatefulSet + PVC (`local/ecom-db` image with init.sql), Secret
  generated from `db.env` (git-ignored), HPA max 4, images `local/ecom-*:dev` imported into k3d.
- `k8s/overlays/aws`: base + Docker Hub images (tags set by Jenkins). The `db` ExternalName Service,
  the `db-credentials` Secret and the `shop-env` ConfigMap are created by Ansible from Terraform outputs.
- Scripts: `scripts/local-k8s-up.sh` (create cluster, build, import, deploy), `scripts/hpa-demo.sh`
  (load + watch scaling), `scripts/check-sync.sh` (nginx config copies match).
- Verified here: `kustomize build` of both overlays, hadolint on all Dockerfiles. Cluster run pending on
  Kareem's PC.

## Part 4 - Prometheus and Grafana

- `monitoring/values.yaml` for kube-prometheus-stack: k3s-irrelevant scrape jobs off (etcd, scheduler,
  controller-manager, proxy), selectors open to all ServiceMonitors/rules, 2-day retention, Grafana admin
  from the `grafana-admin` secret (random password), dashboard sidecar watching all namespaces.
- `monitoring/servicemonitor-shop.yaml`: scrape web/search/payment `/metrics` and the nginx exporter.
- `monitoring/alerts-shop.yaml`: ShopHighErrorRate (>5% 5xx for 2m), ShopPodCrashLooping,
  ShopTargetDown, ShopHPAMaxedOut.
- `monitoring/dashboards/`: "Shop - Golden Signals" (orders/min, traffic, 5xx ratio, p95 latency,
  CPU saturation, nginx) and "Shop - Scaling" (HPA replicas, pod CPU, ready pods, node CPU), generated by
  `generate.py` and loaded from ConfigMaps labelled `grafana_dashboard: "1"`.
- Scripts: `monitoring/install.sh`, `monitoring/port-forward.sh`, `monitoring/alert-demo.sh`
  (ERROR_RATE=0.3 on payment -> alert Pending -> Firing, restored on exit).
