# Automated E-Commerce Deployment Platform — DevOps Project Plan

Nov 24, 2026 · @Kareem

## How to use this plan

You will build all 9 deliverables in 13 working days. Everything runs locally first (Windows + WSL2), then the same artifacts are deployed to AWS only for testing and the demo, and destroyed by a Jenkins job afterwards.

**Decisions already taken**

| Topic | Decision | Why |
| --- | --- | --- |
| Application code | Provided ready-made (`app/` folder in the starter repo): `web`, `search`, `payment` in Python/Flask + PostgreSQL | You only do DevOps work; every service already exposes `/health` and `/metrics` |
| Local Kubernetes | **k3d** (k3s inside Docker) | Same distribution you run on AWS, so manifests behave the same in both places |
| AWS Kubernetes | **k3s on EC2**, provisioned by Terraform, configured by Ansible | Cheaper than EKS and gives Ansible real work |
| Database | PostgreSQL container locally, **Amazon RDS** on AWS | Same engine, only the connection string changes |
| Traffic entry | Nginx (compose) and ingress-nginx (Kubernetes); AWS **ALB** (an ELB type) in front | Covers deliverables 6 and 7 |
| Container registry | Docker Hub (free account) | Simplest for Jenkins to push and k3s to pull |
| Config per environment | Kustomize overlays `local` and `aws` | Built into `kubectl`, no extra tool |
| CI/CD | Jenkins in Docker on your laptop; separate jobs for app pipeline, `infra-apply`, `infra-destroy` | Infra is created and destroyed on demand |
| Deadline | Demo on 7 Dec 2026 | Schedule below has no slack, so cut lines are marked |

**How each part is laid out**

1. **Goal and deliverable** — what you must be able to show.
2. **Concepts** — the few ideas the instructor will ask about.
3. **Phases** — small steps, each ending in a check you can see working.
4. **Lab** — commands and config to type yourself (type them, don't paste; that is how you learn them).
5. **Done when** — the checklist for that part.
6. **Depends on / feeds** — where the part sits in the whole.

The Questions bank at the end mirrors the parts. Study one block each evening after that day's lab.

## Target architecture

One Jenkins on your laptop builds once and deploys the same images to two places: a k3d cluster that runs every day, and a k3s cluster on AWS that exists only while you test or demo.

[Diagram: target architecture · local and AWS — see the online plan doc]

On AWS the database moves out of the cluster into RDS, and an ALB replaces `localhost:8080` as the front door; everything else is identical to local.

## Schedule to 7 December

Local work runs 24 Nov – 2 Dec; AWS work runs 3–6 Dec; 7 Dec is the demo. AWS is only switched on for the days marked “AWS on”, and the destroy job runs at the end of each of those days.

| Day | Date | Part | Phases | AWS |
| --- | --- | --- | --- | --- |
| 1 | Tue 24 Nov | Part 0 — Setup + Git repo | WSL2, Docker Desktop, tools, repo skeleton, branch rules | off |
| 2 | Wed 25 Nov | Part 1 — Docker | Dockerfiles, multi-stage builds, run each service | off |
| 3 | Thu 26 Nov | Part 1 + Part 2 — Compose + Nginx | docker compose stack, Nginx routing, health checks | off |
| 4 | Fri 27 Nov | Part 3 — Kubernetes (base) | k3d cluster, Deployments, Services, ConfigMap, Secret, Postgres StatefulSet | off |
| 5 | Sat 28 Nov | Part 3 — Kubernetes (scale) | ingress-nginx, probes, HPA, load test, Kustomize overlays | off |
| 6 | Sun 29 Nov | Part 4 — Monitoring | kube-prometheus-stack, ServiceMonitors, 2 Grafana dashboards, 2 alerts | off |
| 7 | Mon 30 Nov | Part 5 — Jenkins CI | Jenkins in Docker, credentials, build + test + push stages | off |
| 8 | Tue 1 Dec | Part 5 + Part 6 — CD + rollback | deploy stage, rollout check, smoke test, automatic rollback, manual rollback job | off |
| 9 | Wed 2 Dec | Part 7 — Terraform (local plan only) | state bucket bootstrap, modules, `terraform plan` with no apply | off |
| 10 | Thu 3 Dec | Part 7 — Terraform on AWS | apply VPC, EC2, RDS, S3, ALB; `infra-apply` and `infra-destroy` jobs | **on** → destroy |
| 11 | Fri 4 Dec | Part 8 — Ansible | inventory from Terraform, roles: common, k3s server/agent, app config | **on** → destroy |
| 12 | Sat 5 Dec | Part 9 — Full AWS run | one-click: apply → ansible → deploy → monitor → rollback demo → destroy | **on** → destroy |
| 13 | Sun 6 Dec | Rehearsal + study | timed demo rehearsal, README, diagrams, Questions bank | **on** → destroy |
| — | Mon 7 Dec | **Demo** | apply \~1 hour before, present, destroy right after | **on** → destroy |

[Diagram: phase dependencies · local track, automation, AWS track — see the online plan doc]

If a local part slips, the AWS track slips with it, because Terraform and Ansible are run by Jenkins and reuse the local manifests.

**Cut lines if you fall behind** (drop in this order; the 9 deliverables still stand): Trivy image scan → Alertmanager e-mail → Postgres exporter → second k3s agent node → blue/green demo (keep rolling + automatic rollback).

## Part 0 — Workstation and Git repository (Deliverable 9)

**Goal:** one WSL2 Ubuntu shell with every tool installed, and one Git repository that holds the app, all DevOps code and the docs. Every later part commits into this repo.

**Concepts to know:** WSL2 vs a VM · Docker Desktop WSL2 backend · Git branching (trunk-based with short feature branches) · `.gitignore` for secrets and state · conventional commits.

### Phases

1. **Phase 0.1 — WSL2 + Docker.** Install WSL2 Ubuntu 24.04 and Docker Desktop with “Use WSL 2 based engine” and WSL integration for Ubuntu on. Give WSL at least 8 GB RAM in `%UserProfile%\.wslconfig`.
2. **Phase 0.2 — CLI tools inside Ubuntu.** git, kubectl, k3d, helm, terraform, ansible, aws CLI v2, jq, hey (load tester), hadolint.
3. **Phase 0.3 — Accounts.** GitHub repo, Docker Hub account + access token, AWS account with an IAM user (not root) + MFA, AWS Budget alert at $10.
4. **Phase 0.4 — Repo skeleton.** Unzip the starter repo, commit, push; protect `main` (pull requests only).

### Lab 0

```ini
# C:\Users\<you>\.wslconfig
[wsl2]
memory=10GB
processors=4
```

```bash
# inside Ubuntu (WSL2)
sudo apt update && sudo apt install -y git jq unzip python3-pip pipx ansible
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
# kubectl, terraform, aws cli: follow each vendor's Linux install page
aws configure            # region eu-central-1, IAM user keys
docker run hello-world   # proves Docker Desktop <-> WSL2 integration
```

**Repository layout** (one repo = deliverable 9):

```text
ecommerce-devops/
├── app/                  # PROVIDED: web, search, payment (+ db/init.sql)
├── docker/               # Part 1: docker-compose.yml, .env.example
├── nginx/                # Part 2: nginx.conf
├── k8s/
│   ├── base/             # Part 3: deployments, services, hpa, ingress
│   └── overlays/{local,aws}/
├── monitoring/           # Part 4: helm values, ServiceMonitors, dashboards, alerts
├── jenkins/              # Part 5: Jenkinsfile, Jenkinsfile.infra, jenkins docker setup
├── terraform/
│   ├── bootstrap/        # Part 7: state bucket (applied once)
│   ├── modules/{network,compute,database,storage,loadbalancer}/
│   └── envs/demo/        # main.tf, variables.tf, demo.tfvars
├── ansible/              # Part 8: inventory (generated), roles, playbooks
├── docs/                 # diagrams, demo script
└── .gitignore            # *.tfstate, .terraform/, *.pem, .env, kubeconfig
```

```bash
git init && git add . && git commit -m "chore: starter repo skeleton"
git branch -M main && git remote add origin git@github.com:<you>/ecommerce-devops.git
git push -u origin main
git switch -c feat/docker   # one short branch per part, merge by PR
```

### Done when

- [ ] `docker run hello-world`, `k3d version`, `terraform version`, `ansible --version`, `aws sts get-caller-identity` all work in WSL2
- [ ] Repo pushed with the layout above; `main` protected
- [ ] AWS Budget alert created

**Depends on:** nothing. **Feeds:** every part (all code lives here; Jenkins builds from it).

## Part 1 — Dockerized microservices (Deliverable 1)

**Goal:** each service builds into a small, non-root, health-checked image, and the whole shop runs with one `docker compose up`.

**The provided services** (you do not change their code):

| Service | Port | Talks to | Env vars | Endpoints |
| --- | --- | --- | --- | --- |
| `web` | 8080 | search, payment | `SEARCH_URL`, `PAYMENT_URL`, `IMAGE_BASE_URL`, `FAIL_READY` | `/`, `POST /buy`, `/health`, `/ready`, `/metrics` |
| `search` | 8081 | Postgres | `DATABASE_URL` | `/products`, `/search?q=`, `/health`, `/ready`, `/metrics` |
| `payment` | 8082 | Postgres | `DATABASE_URL` | `POST /pay`, `/orders`, `/health`, `/ready`, `/metrics` |
| `db` | 5432 | — | `POSTGRES_*` | seeded by `app/db/init.sql` |

`/health` = the process is alive (liveness). `/ready` = it can reach the database (readiness). You will wire both into Docker and Kubernetes.

**Concepts to know:** image vs container · layers and build cache · multi-stage builds · `.dockerignore` · non-root user · `HEALTHCHECK` · tags (never deploy `latest`; tag with the Git SHA) · bridge networks and service DNS · volumes.

### Phases

1. **Phase 1.1 — First Dockerfile (`search`).** Write it, build it, run it alone against a throwaway Postgres container.
2. **Phase 1.2 — Harden it.** Multi-stage, `python:3.12-slim`, non-root user, `HEALTHCHECK`, `.dockerignore`. Compare image size before/after with `docker images`.
3. **Phase 1.3 — Repeat for `payment` and `web`.** Same pattern; only port and CMD change.
4. **Phase 1.4 — Compose the stack.** `docker/docker-compose.yml` with db, search, payment, web; `depends_on` with `condition: service_healthy`; named volume for Postgres; `.env` for passwords.
5. **Phase 1.5 — Push.** Tag `docker.io/<you>/ecom-search:<git-sha>` and push all three.

### Lab 1

```dockerfile
# app/search/Dockerfile
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim
RUN useradd --create-home --uid 10001 appuser
WORKDIR /app
COPY --from=builder /install /usr/local
COPY . .
USER appuser
EXPOSE 8081
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request;urllib.request.urlopen('http://localhost:8081/health')"
CMD ["gunicorn", "-b", "0.0.0.0:8081", "-w", "2", "app:app"]
```

```bash
cd app/search
docker build -t ecom-search:dev .
docker network create shopnet
docker run -d --name db --network shopnet -e POSTGRES_PASSWORD=shop -e POSTGRES_DB=shop \
  -v $PWD/../db/init.sql:/docker-entrypoint-initdb.d/init.sql postgres:16-alpine
docker run -d --name search --network shopnet -p 8081:8081 \
  -e DATABASE_URL=postgresql://postgres:shop@db:5432/shop ecom-search:dev
curl localhost:8081/products | jq     # products come back = DB + image work
docker inspect --format '{{.State.Health.Status}}' search
```

```yaml
# docker/docker-compose.yml (core of it)
services:
  db:
    image: postgres:16-alpine
    environment: { POSTGRES_DB: shop, POSTGRES_PASSWORD: "${DB_PASSWORD}" }
    volumes: [ "pgdata:/var/lib/postgresql/data", "../app/db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro" ]
    healthcheck: { test: ["CMD-SHELL", "pg_isready -U postgres"], interval: 5s, retries: 10 }
  search:
    build: ../app/search
    environment: { DATABASE_URL: "postgresql://postgres:${DB_PASSWORD}@db:5432/shop" }
    depends_on: { db: { condition: service_healthy } }
  payment:
    build: ../app/payment
    environment: { DATABASE_URL: "postgresql://postgres:${DB_PASSWORD}@db:5432/shop" }
    depends_on: { db: { condition: service_healthy } }
  web:
    build: ../app/web
    environment: { SEARCH_URL: "http://search:8081", PAYMENT_URL: "http://payment:8082" }
    depends_on: [ search, payment ]
volumes: { pgdata: {} }
```

**Try breaking it (learn by failure):** stop `db` and watch `/ready` turn 503 while `/health` stays 200; remove `USER appuser` and run `docker exec search whoami`; change one line of code and see which layers rebuild.

### Done when

- [ ] 3 images, each under \~200 MB, running as a non-root user, showing `healthy`
- [ ] `docker compose up -d` brings up the whole shop; buying a product creates a row in `orders`
- [ ] Images pushed to Docker Hub with a Git-SHA tag

**Depends on:** Part 0. **Feeds:** Part 2 (Nginx fronts these containers), Part 3 (Kubernetes runs these images), Part 5 (Jenkins builds them).

## Part 2 — Nginx reverse proxy (Deliverable 6)

**Goal:** one entry point on port 80 that routes by path, so no service is exposed directly. The same routing rules carry over to Kubernetes as an Ingress.

| Path | Routed to | Notes |
| --- | --- | --- |
| `/` | `web:8080` | storefront |
| `/api/search/` | `search:8081` | prefix stripped → `/products`, `/search` |
| `/api/payment/` | `payment:8082` | rate-limited (10 req/s per IP) |
| `/nginx_status` | Nginx itself | stub\_status, internal only, later scraped by Prometheus |

**Concepts to know:** reverse vs forward proxy · `upstream` blocks and load balancing (round robin, `least_conn`) · `proxy_pass` with and without trailing slash · `X-Forwarded-For` / `X-Real-IP` headers · timeouts · `limit_req` · gzip · Nginx vs Ingress controller vs ALB (three layers in the AWS design).

### Phases

1. **Phase 2.1 — Basic proxy.** Add an `nginx` service to compose; only it publishes a port (80). Remove `ports:` from every other service.
2. **Phase 2.2 — Path routing.** Add the four locations above; test each with `curl`.
3. **Phase 2.3 — Load balancing.** `docker compose up -d --scale search=3`; watch requests spread in `docker compose logs -f search`.
4. **Phase 2.4 — Hardening.** Headers, timeouts, `limit_req` on payment, gzip, custom 502 page.
5. **Phase 2.5 — Translate to Ingress.** Write `k8s/base/ingress.yaml` with the same paths (used in Part 3).

### Lab 2

```nginx
# nginx/nginx.conf
limit_req_zone $binary_remote_addr zone=pay:10m rate=10r/s;
upstream web_up     { server web:8080; }
upstream search_up  { least_conn; server search:8081; }   # docker DNS returns all replicas
upstream payment_up { server payment:8082; }

server {
  listen 80;
  gzip on;
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_connect_timeout 3s;  proxy_read_timeout 15s;

  location /               { proxy_pass http://web_up; }
  location /api/search/    { proxy_pass http://search_up/; }    # trailing / strips the prefix
  location /api/payment/   { limit_req zone=pay burst=20 nodelay; proxy_pass http://payment_up/; }
  location /nginx_status   { stub_status; allow 172.16.0.0/12; deny all; }
}
```

```bash
curl -i localhost/                       # storefront HTML
curl -s localhost/api/search/search?q=shoe | jq
hey -n 300 -c 50 -m POST localhost/api/payment/pay   # expect some 503 = rate limit works
```

### Done when

- [ ] Only Nginx publishes a host port; all routes answer through it
- [ ] Scaling `search` to 3 spreads load (visible in logs)
- [ ] Rate limit on payment proven with `hey`
- [ ] `ingress.yaml` written with the same paths

**Depends on:** Part 1. **Feeds:** Part 3 (Ingress rules), Part 4 (Nginx metrics), Part 7 (the ALB forwards to the ingress-nginx NodePort).

## Part 3 — Kubernetes with auto-scaling (Deliverable 3)

**Goal:** the shop runs on a local k3d cluster with probes, resource limits, an Ingress and HorizontalPodAutoscalers that add pods under load. The same manifests later run on k3s in AWS through a Kustomize overlay.

**Concepts to know:** Pod, Deployment, ReplicaSet, Service (ClusterIP / NodePort / LoadBalancer / ExternalName), Ingress + controller, ConfigMap vs Secret, StatefulSet + PVC, namespaces · liveness vs readiness vs startup probes · requests vs limits · HPA and metrics-server · rolling update (`maxSurge`, `maxUnavailable`) · Kustomize base/overlays.

**What runs where**

| Object | `base/` | `overlays/local` | `overlays/aws` |
| --- | --- | --- | --- |
| web, search, payment Deployments + Services | yes | 1–4 replicas | 2–6 replicas |
| Ingress (ingress-nginx class) | yes | host `shop.localhost` | any host (ALB in front) |
| HPA for web + search | yes | max 4 | max 6 |
| Database | — | Postgres StatefulSet + PVC | Service `db` of type ExternalName → RDS endpoint |
| Secret `db-credentials` | — | created by hand / script | created by Ansible from Terraform outputs |

### Phases

1. **Phase 3.1 — Cluster.** k3d cluster (1 server, 2 agents), Traefik disabled, port 8080 mapped to the cluster load balancer; install ingress-nginx with Helm.
2. **Phase 3.2 — Database.** Namespace `shop`, Secret, Postgres StatefulSet + headless Service + PVC, init SQL from a ConfigMap.
3. **Phase 3.3 — Services.** One Deployment + Service per app, with env from ConfigMap/Secret, probes on `/health` and `/ready`, requests/limits.
4. **Phase 3.4 — Ingress.** Translate the Nginx rules (Part 2) to `ingress.yaml`; open http://shop.localhost:8080.
5. **Phase 3.5 — Auto-scaling.** HPA at 60% CPU; generate load with `hey`; watch pods scale out and back in.
6. **Phase 3.6 — Kustomize.** Move everything into `base/` + `overlays/local`; deploy with `kubectl apply -k`.

### Lab 3

```bash
k3d cluster create shop --agents 2 -p "8080:80@loadbalancer" \
  --k3s-arg "--disable=traefik@server:0"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
kubectl top nodes          # metrics-server ships with k3s; needed by the HPA
```

```yaml
# k8s/base/search.yaml (Deployment part)
apiVersion: apps/v1
kind: Deployment
metadata: { name: search, labels: { app: search } }
spec:
  replicas: 2
  revisionHistoryLimit: 5            # keeps old ReplicaSets = rollback targets (Part 6)
  strategy: { type: RollingUpdate, rollingUpdate: { maxSurge: 1, maxUnavailable: 0 } }
  selector: { matchLabels: { app: search } }
  template:
    metadata: { labels: { app: search } }
    spec:
      containers:
      - name: search
        image: docker.io/YOU/ecom-search:CHANGE_ME   # Jenkins sets the tag
        ports: [ { containerPort: 8081, name: http } ]
        env:
        - name: DATABASE_URL
          valueFrom: { secretKeyRef: { name: db-credentials, key: url } }
        readinessProbe: { httpGet: { path: /ready, port: http }, periodSeconds: 5 }
        livenessProbe:  { httpGet: { path: /health, port: http }, initialDelaySeconds: 10 }
        resources:
          requests: { cpu: 100m, memory: 128Mi }    # HPA % is measured against requests
          limits:   { cpu: 500m, memory: 256Mi }
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: { name: search }
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: search }
  minReplicas: 2
  maxReplicas: 6
  metrics:
  - type: Resource
    resource: { name: cpu, target: { type: Utilization, averageUtilization: 60 } }
```

```yaml
# k8s/overlays/aws/db-external.yaml  (the AWS overlay swaps Postgres for RDS)
apiVersion: v1
kind: Service
metadata: { name: db }
spec: { type: ExternalName, externalName: RDS_ENDPOINT_FROM_TERRAFORM }
```

```bash
kubectl apply -k k8s/overlays/local
kubectl -n shop get pods,svc,ingress,hpa
hey -z 2m -c 80 http://shop.localhost:8080/api/search/search?q=a &
kubectl -n shop get hpa search -w        # REPLICAS climbs 2 -> 6, then back after ~5 min
```

**Try breaking it:** delete a pod and watch the ReplicaSet replace it; scale the database to 0 and watch readiness remove pods from the Service endpoints (`kubectl get endpoints`); set a bad image tag and watch the rollout stall without downtime (this is the base of Part 6).

### Done when

- [ ] All pods Ready; shop reachable at http://shop.localhost:8080 through ingress-nginx
- [ ] HPA scales `search` out under `hey` load and back in afterwards (screenshot for the report)
- [ ] `kubectl apply -k k8s/overlays/local` rebuilds everything from scratch

**Depends on:** Parts 1–2. **Feeds:** Part 4 (what to monitor), Part 5 (what Jenkins deploys), Part 6 (rollouts to undo), Part 8 (same manifests on AWS).

## Part 4 — Prometheus and Grafana monitoring (Deliverable 5)

**Goal:** Prometheus scrapes every service, node and Kubernetes object; Grafana shows two dashboards stored as code; two alerts fire when something breaks. The same Helm values are reused on AWS.

**Metrics the provided services already expose** at `/metrics`:

| Metric | Type | Labels | Used for |
| --- | --- | --- | --- |
| `http_requests_total` | counter | `service`, `endpoint`, `status` | request rate, error rate |
| `http_request_duration_seconds` | histogram | `service`, `endpoint` | p95 latency |
| `shop_orders_total` | counter | — | business KPI: orders/min |
| `shop_payment_failures_total` | counter | `reason` | payment health |

[Diagram: monitoring data flow · 4 sources, 3 consumers — see the online plan doc]

Instructors often ask whether the HPA uses Prometheus. In this design it does not: it reads CPU from metrics-server, while Prometheus is for dashboards, alerts and the pipeline's error-rate gate.

**Concepts to know:** pull model and scrape interval · exporters (node-exporter, kube-state-metrics) · the four metric types · PromQL `rate()`, `sum by`, `histogram_quantile()` · the Prometheus Operator, `ServiceMonitor` and `PrometheusRule` CRDs · Alertmanager routing · the golden signals (latency, traffic, errors, saturation) · dashboards as code.

### Phases

1. **Phase 4.1 — Install the stack.** `kube-prometheus-stack` Helm chart into namespace `monitoring` (Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics).
2. **Phase 4.2 — Scrape the shop.** One `ServiceMonitor` selecting `app in (web, search, payment)`; confirm targets are UP in Prometheus → Status → Targets.
3. **Phase 4.3 — Learn PromQL.** Run the five queries below in the Prometheus UI before building panels.
4. **Phase 4.4 — Dashboards as code.** Build “Shop — Golden Signals” and “Shop — Scaling” in Grafana, export JSON, store in `monitoring/dashboards/`, load via a ConfigMap labelled `grafana_dashboard: "1"`.
5. **Phase 4.5 — Alerts.** `PrometheusRule` with `ShopHighErrorRate` and `ShopPodCrashLooping`; trigger each on purpose.

### Lab 4

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f monitoring/values.yaml
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80   # http://localhost:3000
```

```yaml
# monitoring/servicemonitor-shop.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata: { name: shop, namespace: monitoring, labels: { release: monitoring } }
spec:
  namespaceSelector: { matchNames: [ shop ] }
  selector: { matchExpressions: [ { key: app, operator: In, values: [web, search, payment] } ] }
  endpoints: [ { port: http, path: /metrics, interval: 15s } ]
```

```promql
sum by (service) (rate(http_requests_total[1m]))                                   # traffic
sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
  / sum by (service) (rate(http_requests_total[5m]))                                # error ratio
histogram_quantile(0.95, sum by (le, service) (rate(http_request_duration_seconds_bucket[5m])))  # p95
sum(rate(shop_orders_total[5m])) * 60                                              # orders per minute
kube_horizontalpodautoscaler_status_current_replicas{namespace="shop"}              # scaling
```

```yaml
# monitoring/alerts-shop.yaml (one of the two rules)
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata: { name: shop-alerts, namespace: monitoring, labels: { release: monitoring } }
spec:
  groups:
  - name: shop
    rules:
    - alert: ShopHighErrorRate
      expr: |
        sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
          / sum by (service) (rate(http_requests_total[5m])) > 0.05
      for: 2m
      labels: { severity: critical }
      annotations: { summary: "{{ $labels.service }} 5xx above 5% for 2m" }
```

**Try breaking it:** scale `db` to 0 and watch the error-rate panel and `ShopHighErrorRate` go Pending → Firing; run the Part 3 load test and watch the Scaling dashboard line up CPU with replica count.

### Done when

- [ ] All shop targets UP in Prometheus
- [ ] Two dashboards load automatically from Git (delete Grafana pod → they come back)
- [ ] Both alerts demonstrated firing and resolving

**Depends on:** Part 3. **Feeds:** Part 5/6 (the pipeline can check the error rate after a deploy), Part 9 (live dashboards in the demo).

## Part 5 — Jenkins CI/CD pipelines (Deliverable 2)

**Goal:** a push to `main` builds, tests, pushes and deploys all three services with no manual step, to the local cluster or to AWS (a parameter picks which). Infra has its own jobs.

**The four Jenkins jobs**

| Job | File | Trigger | What it does |
| --- | --- | --- | --- |
| `shop-pipeline` | `jenkins/Jenkinsfile` | Poll SCM every 2 min on `main` (a laptop can't receive GitHub webhooks without a tunnel) | CI + CD for web, search, payment |
| `shop-rollback` | `jenkins/Jenkinsfile.rollback` | manual, parameter `SERVICE`, `REVISION` | roll a service back to a chosen revision (Part 6) |
| `infra-apply` | `jenkins/Jenkinsfile.infra` (`ACTION=apply`) | manual | Terraform apply → Ansible → deploy to AWS (Parts 7–8) |
| `infra-destroy` | `jenkins/Jenkinsfile.infra` (`ACTION=destroy`) | manual **and** nightly at 23:00 Cairo time | `terraform destroy` so nothing is left running (Part 7) |

**Concepts to know:** CI vs continuous delivery vs continuous deployment · declarative pipeline syntax (`agent`, `stages`, `steps`, `post`, `parameters`, `environment`, `when`) · Jenkins credentials and `withCredentials` · `parallel` stages · artifact versioning by Git SHA · pipeline as code · build once, deploy many.

### Pipeline stages (in order)

1. **Checkout** — `GIT_SHA = git rev-parse --short HEAD` becomes the image tag.
2. **Lint** — `hadolint` on Dockerfiles, `kubectl kustomize` renders the overlay (catches YAML errors before deploy).
3. **Build** — three images in `parallel`.
4. **Test** — `docker compose up` the stack, curl `/health` and one purchase through Nginx, then tear down.
5. **Push** — `ecom-<svc>:<GIT_SHA>` to Docker Hub with the `dockerhub` credential.
6. **Deploy** — `kustomize edit set image` to the new tag, `kubectl apply -k k8s/overlays/${TARGET_ENV}`.
7. **Verify** — `kubectl rollout status --timeout=120s` for each Deployment, then a smoke test through the Ingress.
8. **post { failure }** — automatic rollback (Part 6) and a red build.

### Phases

1. **Phase 5.1 — Jenkins in Docker.** Custom image (Jenkins LTS + docker CLI, kubectl, terraform, ansible, aws CLI), Docker socket mounted, attached to the `k3d-shop` network so it can reach the cluster.
2. **Phase 5.2 — Credentials.** `dockerhub` (username + token), `kubeconfig-local`, `kubeconfig-aws` (secret files; for AWS the pipeline can instead read the kubeconfig file Ansible writes, see Part 8), `aws-creds`, `db-password`.
3. **Phase 5.3 — CI half.** Stages 1–5; make a commit and watch the Stage View.
4. **Phase 5.4 — CD half.** Stages 6–8 against `TARGET_ENV=local`.
5. **Phase 5.5 — Prove it end to end.** Change the storefront title in `app/web`, push, and watch the new version reach the browser with zero failed requests (`hey` running during the deploy).

### Lab 5

```dockerfile
# jenkins/Dockerfile
FROM jenkins/jenkins:lts-jdk17
USER root
RUN apt-get update && apt-get install -y docker.io python3-pip ansible unzip curl \
 && curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
 && chmod +x /usr/local/bin/kubectl
# + terraform and aws cli (same pattern) and plugins: git, workflow-aggregator, docker-workflow, credentials-binding
USER jenkins
```

```bash
docker build -t my-jenkins jenkins/
docker run -d --name jenkins -p 8090:8080 --network k3d-shop --group-add $(stat -c %g /var/run/docker.sock) \
  -v jenkins_home:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock my-jenkins
# kubeconfig Jenkins can use from inside the k3d network:
k3d kubeconfig get shop | sed -E 's#https://0.0.0.0:[0-9]+#https://k3d-shop-serverlb:6443#' > kubeconfig-local
```

```groovy
// jenkins/Jenkinsfile (shape; fill each sh step in the lab)
pipeline {
  agent any
  parameters { choice(name: 'TARGET_ENV', choices: ['local', 'aws'], description: 'Where to deploy') }
  environment { REG = 'docker.io/YOU'; SERVICES = 'web search payment' }
  triggers { pollSCM('H/2 * * * *') }
  options { timestamps(); disableConcurrentBuilds() }
  stages {
    stage('Checkout') { steps { checkout scm; script { env.GIT_SHA = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim() } } }
    stage('Lint')     { steps { sh 'for s in $SERVICES; do docker run --rm -i hadolint/hadolint < app/$s/Dockerfile; done' } }
    stage('Build') {
      parallel {
        stage('web')     { steps { sh 'docker build -t $REG/ecom-web:$GIT_SHA app/web' } }
        stage('search')  { steps { sh 'docker build -t $REG/ecom-search:$GIT_SHA app/search' } }
        stage('payment') { steps { sh 'docker build -t $REG/ecom-payment:$GIT_SHA app/payment' } }
      }
    }
    stage('Test') { steps { sh './jenkins/scripts/compose-smoke-test.sh' } }
    stage('Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'U', passwordVariable: 'P')]) {
          sh 'echo $P | docker login -u $U --password-stdin && for s in $SERVICES; do docker push $REG/ecom-$s:$GIT_SHA; done'
        }
      }
    }
    stage('Deploy') {
      steps {
        withCredentials([file(credentialsId: "kubeconfig-${params.TARGET_ENV}", variable: 'KUBECONFIG')]) {
          dir("k8s/overlays/${params.TARGET_ENV}") {
            sh 'for s in $SERVICES; do kustomize edit set image $REG/ecom-$s=$REG/ecom-$s:$GIT_SHA; done'
          }
          sh "kubectl apply -k k8s/overlays/${params.TARGET_ENV}"
        }
      }
    }
    stage('Verify') {
      steps {
        withCredentials([file(credentialsId: "kubeconfig-${params.TARGET_ENV}", variable: 'KUBECONFIG')]) {
          sh 'for s in $SERVICES; do kubectl -n shop rollout status deploy/$s --timeout=120s; done'
          sh './jenkins/scripts/smoke-test.sh ${TARGET_ENV}'
        }
      }
    }
  }
  post {
    failure {
      withCredentials([file(credentialsId: "kubeconfig-${params.TARGET_ENV}", variable: 'KUBECONFIG')]) {
        sh './jenkins/scripts/rollback.sh $TARGET_ENV'     // Part 6
      }
    }
  }
}
```

Put the standalone `kustomize` binary in the Jenkins image: `kubectl` can apply an overlay (`-k`) but cannot edit it. Jenkins exposes every parameter as an environment variable, so `$TARGET_ENV` works inside single-quoted `sh` steps.

### Done when

- [ ] A commit to `main` reaches the local cluster with no manual step, in under \~6 minutes
- [ ] Every image in the cluster carries a Git-SHA tag you can trace back to a commit
- [ ] Zero failed requests during a deploy (`hey` output in the report)
- [ ] Same pipeline deploys to AWS with `TARGET_ENV=aws` (proven on day 12)

**Depends on:** Parts 1, 3 (and 4 for the metric check). **Feeds:** Part 6 (rollback hooks into `post`), Part 9 (the demo is driven from Jenkins).

## Part 6 — Automated rollback strategies (Deliverable 8)

**Goal:** a bad release never takes the shop down, and is undone without a human. You show four layers of protection, from “bad pods never get traffic” to “undo the infrastructure change”.

| # | Layer | Mechanism | Trigger | Automatic? |
| --- | --- | --- | --- | --- |
| 1 | Kubernetes | Rolling update with `maxUnavailable: 0` + readiness probe: new pods that never get Ready never receive traffic; old pods keep serving | Probe fails | yes (built in) |
| 2 | Pipeline | `rollout status --timeout` or smoke test fails → `post { failure }` runs `kubectl rollout undo` for each service | Failed Verify stage | yes |
| 3 | Metrics | After deploy, the pipeline queries Prometheus for the 5xx ratio for 2 min; above 5% → rollback | Error rate | yes (stretch goal) |
| 4 | Manual by version | `shop-rollback` job: pick service + revision from `kubectl rollout history` (or redeploy an older Git-SHA tag) | Human decision | one click |
| 5 | Infrastructure | Terraform: `git revert` the change and re-apply; S3 state bucket versioning restores a damaged state file; RDS automated backups/snapshots for data | Bad infra change | scripted |

[Diagram: rollback decision flow · 2 checks, 1 undo path — see the online plan doc]

Both checks lead to the same undo path, so a release that never gets Ready and a release that gets Ready but returns errors are handled the same way.

**Concepts to know:** rollback vs roll-forward · ReplicaSet revision history (`revisionHistoryLimit`) · `kubectl rollout history/undo --to-revision` · immutable image tags · blue/green vs canary vs rolling · backward-compatible database changes (expand → migrate → contract) · MTTR.

### Phases

1. **Phase 6.1 — Prove layer 1.** Deploy an image whose `/ready` always fails (the provided `web` honours `FAIL_READY=true`); show the old version keeps serving.
2. **Phase 6.2 — Script layer 2.** `jenkins/scripts/rollback.sh` + `post { failure }`; break a release on purpose and watch Jenkins undo it.
3. **Phase 6.3 — Manual job (layer 4).** `Jenkinsfile.rollback` with `SERVICE` and `REVISION` parameters.
4. **Phase 6.4 — Metric gate (layer 3, stretch).** Prometheus API query in the Verify stage; the provided `payment` honours `ERROR_RATE=0.3` to fake errors.
5. **Phase 6.5 — Infra rollback (layer 5).** Turn on versioning in the state bucket (done in Part 7 bootstrap); practise restoring a previous state version once.

### Lab 6

```bash
#!/usr/bin/env bash
# jenkins/scripts/rollback.sh <env>
set -euo pipefail
for s in web search payment; do
  rev=$(kubectl -n shop rollout history deploy/$s | tail -n 2 | head -n 1 | awk '{print $1}')
  echo "Rolling back $s (current revision $rev)"
  kubectl -n shop rollout undo deploy/$s
  kubectl -n shop rollout status deploy/$s --timeout=120s
done
```

```bash
# metric gate (layer 3) inside the Verify stage
sleep 120
RATIO=$(curl -s "$PROM/api/v1/query" --data-urlencode \
  'query=sum(rate(http_requests_total{status=~"5.."}[2m]))/sum(rate(http_requests_total[2m]))' \
  | jq -r '.data.result[0].value[1] // "0"')
awk -v r="$RATIO" 'BEGIN { exit (r > 0.05) }' || { echo "5xx ratio $RATIO > 5%"; exit 1; }
```

```bash
# manual practice
kubectl -n shop set env deploy/web FAIL_READY=true       # bad release
kubectl -n shop rollout status deploy/web --timeout=60s   # times out, site still up
kubectl -n shop rollout history deploy/web
kubectl -n shop rollout undo deploy/web --to-revision=<n>
```

### Done when

- [ ] A deliberately broken release is rolled back by Jenkins with no human action, and the site never returns errors (keep `hey` running)
- [ ] `shop-rollback` job restores a chosen revision
- [ ] You can explain all five layers and when each one acts

**Depends on:** Parts 3–5. **Feeds:** Part 9 (the rollback is the highlight of the demo).

## Part 7 — Terraform for AWS EC2, RDS, S3, ELB (Deliverable 7)

**Goal:** one `terraform apply` builds the whole AWS environment in about 10–15 minutes (RDS is the slow part), and one `terraform destroy` (run by a Jenkins job) removes all of it. Nothing on AWS is created by clicking in the console.

**What Terraform creates** (region `eu-central-1`, all tagged `Project=ecommerce-devops`, `Owner=kareem`, `TTL=demo`):

| Module | Resources | Key settings |
| --- | --- | --- |
| `network` | VPC 10.0.0.0/16, 2 public + 2 private subnets in 2 AZs, Internet Gateway, route tables | No NAT gateway (saves money): nodes sit in public subnets, locked down by security groups |
| `compute` | 1 k3s server (t3.medium) + `var.agent_count` agents (t3.small), key pair, node security group | Ubuntu 24.04 AMI found by a `data` source; SSH only from your IP |
| `database` | RDS PostgreSQL 16 (db.t3.micro), DB subnet group (private subnets), DB security group | Port 5432 only from the node SG; `skip_final_snapshot = true`, `deletion_protection = false` for the demo |
| `storage` | S3 bucket for product images (random suffix), versioning, public read on `images/*` only | `force_destroy = true` so destroy never gets stuck on objects |
| `loadbalancer` | Application Load Balancer, target group on NodePort 30080, HTTP listener :80 | Health check `/healthz` on ingress-nginx |
| `bootstrap` (separate, applied once, never destroyed) | S3 state bucket with versioning, encryption, public access block | Remote state + locking with `use_lockfile = true` (Terraform ≥ 1.10, no DynamoDB needed) |

[Diagram: AWS layout built by Terraform · modules marked on each part — see the online plan doc]

Each box names the Terraform module that creates it, so the picture doubles as a map of `terraform/modules/`.

**Rough cost while running:** about $0.10–0.15 per hour for everything above (approximate on-demand prices; check the AWS Pricing Calculator for your region). A 3-hour test day is well under $1 if the destroy job runs.

**Concepts to know:** providers, resources, data sources · state and why it is remote + locked · `plan` / `apply` / `destroy` · modules, inputs, outputs · `count` vs `for_each` · `dynamic` blocks · `locals` and `merge()` for tags · variable validation · `.tfvars` per environment and workspaces · dependency graph (implicit references vs `depends_on`) · drift and `terraform plan -refresh-only` · never commit state or secrets.

### Phases

1. **Phase 7.1 — Bootstrap state (local only).** `terraform/bootstrap` creates the state bucket; it keeps its own local state.
2. **Phase 7.2 — Network module.** Apply, look in the console, destroy. First AWS contact; small and cheap.
3. **Phase 7.3 — Compute + storage modules.** EC2 nodes and the images bucket; SSH into the server.
4. **Phase 7.4 — Database + load balancer modules.** RDS and ALB; full `apply` end to end; outputs printed.
5. **Phase 7.5 — Hand-off to Ansible.** Terraform writes `ansible/inventory/aws.ini` and `ansible/group_vars/all/tf.yml` (RDS endpoint, bucket name) from templates.
6. **Phase 7.6 — Jenkins jobs.** `infra-apply` and `infra-destroy` (manual + nightly), tested apply → destroy twice.

### Lab 7 — core code

```hcl
# terraform/envs/demo/backend.tf
terraform {
  required_version = ">= 1.10"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } }
  backend "s3" {
    bucket       = "kareem-ecom-tfstate"     # created by bootstrap
    key          = "demo/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
}
provider "aws" {
  region = var.region
  default_tags { tags = local.tags }
}
```

```hcl
# terraform/envs/demo/main.tf
locals { tags = { Project = "ecommerce-devops", Owner = var.owner, Env = terraform.workspace, TTL = "demo" } }

module "network" {
  source   = "../../modules/network"
  cidr     = var.vpc_cidr
  az_count = 2
}
module "compute" {
  source         = "../../modules/compute"
  subnet_ids     = module.network.public_subnet_ids
  vpc_id         = module.network.vpc_id
  agent_count    = var.agent_count
  admin_cidr     = var.my_ip_cidr
  public_key     = file(var.public_key_path)
}
module "database" {
  source        = "../../modules/database"
  count         = var.enable_rds ? 1 : 0          # dynamic: switch RDS off for cheap tests
  subnet_ids    = module.network.private_subnet_ids
  vpc_id        = module.network.vpc_id
  allowed_sg_id = module.compute.node_sg_id
  db_password   = var.db_password                 # from Jenkins credential, never in Git
}
module "storage"      { source = "../../modules/storage" }
module "loadbalancer" {
  source        = "../../modules/loadbalancer"
  vpc_id        = module.network.vpc_id
  subnet_ids    = module.network.public_subnet_ids
  instance_ids  = module.compute.all_instance_ids
  node_port     = 30080
  node_sg_id    = module.compute.node_sg_id
}

resource "local_file" "inventory" {
  filename = "${path.module}/../../../ansible/inventory/aws.ini"
  content  = templatefile("${path.module}/inventory.tftpl", {
    server = module.compute.server_public_ip
    agents = module.compute.agent_public_ips
  })
}
```

```hcl
# terraform/modules/compute/sg.tf — dynamic block driven by a variable
variable "node_ingress" {
  type = map(object({ port = number, cidrs = list(string) }))
  default = {
    ssh      = { port = 22,    cidrs = [] }          # filled with admin_cidr below
    k8s_api  = { port = 6443,  cidrs = [] }
    nodeport = { port = 30080, cidrs = ["10.0.0.0/16"] }   # only the ALB inside the VPC
  }
}
resource "aws_security_group" "node" {
  vpc_id = var.vpc_id
  dynamic "ingress" {
    for_each = var.node_ingress
    content {
      description = ingress.key
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = length(ingress.value.cidrs) > 0 ? ingress.value.cidrs : [var.admin_cidr]
    }
  }
  ingress {                       # node-to-node (k3s API, flannel VXLAN, kubelet)
    self      = true
    from_port = 0
    to_port   = 0
    protocol  = "-1"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

```hcl
# terraform/envs/demo/variables.tf (validation examples)
variable "agent_count" {
  type    = number
  default = 1
  validation {
    condition     = var.agent_count >= 0 && var.agent_count <= 3
    error_message = "Keep 0-3 agents to control cost."
  }
}
variable "enable_rds" {
  type    = bool
  default = true
}
# HCL rule: a block written on one line may hold only ONE argument
```

```groovy
// jenkins/Jenkinsfile.infra — one file, two jobs (ACTION=apply | destroy)
pipeline {
  agent any
  parameters { choice(name: 'ACTION', choices: ['apply', 'destroy']) ; booleanParam(name: 'DEPLOY_APP', defaultValue: true) }
  triggers { cron('TZ=Africa/Cairo\n0 23 * * *') }      // nightly safety net (destroy job only)
  environment { TF_DIR = 'terraform/envs/demo'; TF_IN_AUTOMATION = 'true' }
  stages {
    stage('Init') { steps { withAWS() { sh 'terraform -chdir=$TF_DIR init -input=false' } } }
    stage('Plan') { steps { withAWS() { sh "terraform -chdir=${env.TF_DIR} plan -input=false -var-file=demo.tfvars ${params.ACTION == 'destroy' ? '-destroy' : ''} -out=tfplan" } } }
    stage('Approve') { when { expression { params.ACTION == 'destroy' && currentBuild.getBuildCauses('hudson.triggers.TimerTrigger$TimerTriggerCause').isEmpty() } }
                       steps { input 'Destroy ALL demo resources?' } }
    stage('Apply plan') { steps { withAWS() { sh 'terraform -chdir=$TF_DIR apply -input=false tfplan' } } }
    stage('Ansible')    { when { expression { params.ACTION == 'apply' } } steps { sh 'cd ansible && ansible-playbook site.yml' } }
    stage('Deploy app') { when { expression { params.ACTION == 'apply' && params.DEPLOY_APP } }
                          steps { build job: 'shop-pipeline', parameters: [string(name: 'TARGET_ENV', value: 'aws')] } }
  }
}
// withAWS() here is shorthand: use the "Pipeline: AWS Steps" plugin, withAWS(credentials: 'aws-creds', region: 'eu-central-1'),
// nested with withCredentials([string(credentialsId: 'db-password', variable: 'TF_VAR_db_password')]).
// Enable the cron trigger only on the infra-destroy job.
```

The plan file (`-out=tfplan`) means Jenkins applies exactly what it showed you. The nightly trigger skips the approval step, so a forgotten demo is always cleaned up.

### Dynamic Terraform labs (do these to really learn it)

| Lab | Change | What you learn | Check |
| --- | --- | --- | --- |
| 7-A | `agent_count = 0 → 2` and back | `count`, how plan shows add/destroy | `terraform plan` shows exactly 2 instances + 2 target attachments |
| 7-B | Turn subnets from `count` into `for_each` over a map of AZ → CIDR | why `for_each` is safer when items are removed from the middle | `terraform state list` addresses change from `[0]` to `["eu-central-1a"]` |
| 7-C | Add an `http` rule to `node_ingress` via `demo.tfvars` only | `dynamic` blocks driven by data, no code change | new SG rule in plan, nothing else |
| 7-D | `enable_rds = false` | conditional modules with `count`, and `one(module.database[*].endpoint)` for outputs | plan destroys only RDS |
| 7-E | `terraform workspace new test` + `test.tfvars` with a smaller instance | workspaces and per-env tfvars; tag `Env` changes automatically | two separate state files under the bucket |
| 7-F | Set `agent_count = 9` | variable validation | plan fails with your message |
| 7-G | Change an instance tag in the console, then `plan -refresh-only` | drift detection | plan reports the drift |
| 7-H | Restore an older version of `demo/terraform.tfstate` from bucket versioning | state recovery (Part 6, layer 5) | `terraform plan` matches the older state |

### Done when

- [ ] `infra-apply` builds everything from zero; outputs show ALB DNS name, RDS endpoint, server IP
- [ ] `infra-destroy` removes everything; AWS console shows no running EC2, RDS, ALB (only the state bucket stays)
- [ ] Nightly destroy job enabled; AWS Budget alert in place
- [ ] Labs 7-A to 7-F done (7-G, 7-H if time)

**Depends on:** Part 0 (AWS account), Part 5 (Jenkins). **Feeds:** Part 8 (inventory + variables), Part 9 (the AWS demo).

## Part 8 — Ansible server and configuration setup (Deliverable 4)

**Goal:** Ansible turns the bare EC2 instances Terraform created into a working k3s cluster with ingress, monitoring and the app's config, and running it twice changes nothing the second time (idempotent).

**Terraform → Ansible hand-off:** Terraform writes `ansible/inventory/aws.ini` (hosts) and `ansible/group_vars/all/tf.yml` (RDS endpoint, bucket name, ALB DNS). Ansible never asks you for an IP.

| Role | Runs on | Tasks |
| --- | --- | --- |
| `common` | all nodes | apt update/upgrade, base packages, timezone `Africa/Cairo`, sysctl for Kubernetes networking, unattended-upgrades, disable password SSH |
| `k3s_server` | `[server]` | install pinned k3s version with `--disable traefik --tls-san <public_ip>`, read node token, fetch kubeconfig and rewrite its server address |
| `k3s_agent` | `[agents]` | join the server with the token |
| `platform` | `[server]` (via `kubernetes.core.helm`) | ingress-nginx as NodePort 30080 (the ALB target), kube-prometheus-stack with your `monitoring/values.yaml` + dashboards |
| `app_config` | `[server]` | namespace `shop`, Secret `db-credentials` built from RDS endpoint + password, render `k8s/overlays/aws/db-external.yaml` with the RDS endpoint |

**Concepts to know:** agentless push over SSH · inventory and groups · playbooks, plays, tasks, handlers · roles and their folder layout · variables and precedence (group\_vars, host\_vars, extra vars) · facts · idempotency (`creates:`, `changed_when`) · Jinja2 templates · Ansible Vault · `--check --diff`.

### Phases

1. **Phase 8.1 — Practise locally first (free).** Run `common` against a throwaway container or `localhost` in WSL2 with `--check --diff`.
2. **Phase 8.2 — Inventory + connectivity.** After Terraform apply: `ansible all -m ping`.
3. **Phase 8.3 — Cluster roles.** `k3s_server`, `k3s_agent`; verify `kubectl get nodes` from WSL2 with the fetched kubeconfig.
4. **Phase 8.4 — Platform + app config.** ingress-nginx, monitoring, Secret, ExternalName; the ALB target group turns healthy.
5. **Phase 8.5 — Idempotency proof.** Run `site.yml` a second time: `changed=0` on every host. Screenshot it.

### Lab 8

```ini
# ansible/inventory/aws.ini  (generated by Terraform — do not edit)
[server]
k3s-server ansible_host=3.70.x.x
[agents]
k3s-agent-1 ansible_host=18.192.x.x
[k3s:children]
server
agents
[k3s:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/ecom-demo
```

```yaml
# ansible/site.yml
- hosts: k3s
  become: true
  roles: [ common ]
- hosts: server
  become: true
  roles: [ k3s_server ]
- hosts: agents
  become: true
  roles: [ k3s_agent ]
- hosts: server
  roles: [ platform, app_config ]
```

```yaml
# ansible/roles/k3s_server/tasks/main.yml
- name: Install k3s server (skipped if already installed = idempotent)
  ansible.builtin.shell: >
    curl -sfL https://get.k3s.io |
    INSTALL_K3S_VERSION={{ k3s_version }}
    INSTALL_K3S_EXEC="server --disable traefik --tls-san {{ ansible_host }} --write-kubeconfig-mode 644" sh -
  args: { creates: /usr/local/bin/k3s }

- name: Read join token
  ansible.builtin.slurp: { src: /var/lib/rancher/k3s/server/node-token }
  register: k3s_token

- name: Share token with agents
  ansible.builtin.set_fact: { k3s_join_token: "{{ k3s_token.content | b64decode | trim }}" }

- name: Fetch kubeconfig for Jenkins
  ansible.builtin.fetch: { src: /etc/rancher/k3s/k3s.yaml, dest: "{{ kubeconfig_out }}", flat: true }

- name: Point kubeconfig at the public IP
  ansible.builtin.replace: { path: "{{ kubeconfig_out }}", regexp: "127.0.0.1", replace: "{{ ansible_host }}" }
  delegate_to: localhost
  become: false
```

```yaml
# ansible/roles/k3s_agent/tasks/main.yml
- name: Join cluster
  ansible.builtin.shell: >
    curl -sfL https://get.k3s.io |
    INSTALL_K3S_VERSION={{ k3s_version }}
    K3S_URL=https://{{ hostvars[groups['server'][0]].ansible_host }}:6443
    K3S_TOKEN={{ hostvars[groups['server'][0]].k3s_join_token }} sh -
  args: { creates: /usr/local/bin/k3s-agent-uninstall.sh }
```

`kubeconfig_out` points to `/var/jenkins_home/kubeconfigs/aws.yaml`. The server IP changes on every apply, so the pipeline reads this file for `TARGET_ENV=aws` instead of a stored credential. The DB password arrives as an extra var from the Jenkins credential; for runs from your shell keep it in `group_vars/all/vault.yml` encrypted with `ansible-vault`.

### Done when

- [ ] `ansible-playbook site.yml` builds the cluster from bare instances; `kubectl get nodes` shows all Ready
- [ ] ALB target group healthy; `http://<alb-dns>/` shows the shop once the app is deployed
- [ ] Second run reports `changed=0`
- [ ] No secret in Git in plain text

**Depends on:** Part 7 (hosts, outputs), Parts 3–4 (manifests and Helm values it applies). **Feeds:** Part 5 (`TARGET_ENV=aws` deploys), Part 9.

## Part 9 — AWS demo day, cost guardrails and demo script

**Goal:** on 7 Dec you build the AWS environment from nothing, show every deliverable live in about 20 minutes, and destroy it while the instructor watches.

### Cost guardrails (set up on day 10, before the first apply)

- [ ] AWS Budget: $10/month with e-mail alerts at 50% and 100%
- [ ] Every resource tagged `Project=ecommerce-devops`; Cost Explorer filtered by that tag
- [ ] `infra-destroy` cron at 23:00 Cairo time every night, with no approval step on timer runs
- [ ] After every destroy: EC2 → Instances, RDS → Databases, EC2 → Load Balancers, EC2 → Elastic IPs all empty
- [ ] No NAT gateway, no EKS, nothing outside `eu-central-1`
- [ ] Day 10–11 tests: use `enable_rds = false` and `agent_count = 0` while you debug Ansible (RDS adds \~5–10 min to each apply)

### Timeline on demo day

| Time | Action |
| --- | --- |
| T−60 min | Run `infra-apply` (Terraform → Ansible → `shop-pipeline` with `TARGET_ENV=aws`). Grab the ALB DNS name. |
| T−15 min | Open tabs: Jenkins, GitHub repo, shop via ALB, Grafana (port-forward), Prometheus targets, AWS console. Start a light `hey` load. |
| T+0 | Present (script below). |
| T+25 min | Run `infra-destroy` live; show the console emptying. |

### Demo script (\~20 minutes)

1. **The problem and the architecture (2 min)** — the architecture diagram above; downtime and manual deploys are what you remove.
2. **Git repo (1 min)** — folder layout = one folder per deliverable; branch protection; commit history.
3. **Terraform (3 min)** — modules, remote state in S3, the dynamic `agent_count` / `enable_rds` variables, the `infra-apply` console output; AWS console showing EC2, RDS, S3, ALB.
4. **Ansible (2 min)** — roles, generated inventory, the `changed=0` second run screenshot.
5. **Kubernetes (3 min)** — `kubectl get nodes,pods,hpa -n shop` on AWS; the shop working through the ALB → ingress-nginx → services; a purchase hitting RDS.
6. **CI/CD (3 min)** — change the storefront title, push, show the Jenkins stages, new version live, zero errors in `hey`.
7. **Auto-scaling (2 min)** — heavier `hey` load; HPA replicas climb on the Grafana Scaling dashboard.
8. **Rollback (3 min)** — push a release with `FAIL_READY=true`; Verify fails; Jenkins rolls back automatically; the site never went down. Then one-click `shop-rollback`.
9. **Monitoring (1 min)** — Golden Signals dashboard, an alert firing (scale payment to 0 for a moment).
10. **Destroy (1 min)** — run `infra-destroy`; explain the nightly safety net and cost tags.

**Backup plan:** record a full run on 6 Dec (screen recording). If AWS or the network fails on the day, show the recording plus the same flow live on the local k3d cluster — every part works there too.

### Final submission checklist

- [ ] Repo public (or shared), README with architecture diagram, how to run locally, how to deploy to AWS, how to destroy
- [ ] Screenshots in `docs/`: HPA scaling, Grafana dashboards, Jenkins stage view, rollback build, Ansible `changed=0`, Terraform outputs, empty console after destroy
- [ ] `terraform destroy` confirmed after the demo; Budget shows the spend

**Depends on:** all parts. **Feeds:** your grade.

## Questions bank

Answer each question out loud before reading the answer. Questions marked ★ are the ones instructors ask most about this kind of project.

### Whole project

| # | Question | Answer |
| --- | --- | --- |
| G1 ★ | Walk me through what happens from `git push` to a user seeing the change. | Jenkins polls Git, builds 3 images tagged with the commit SHA, runs a compose smoke test, pushes to Docker Hub, updates the Kustomize overlay to the new tag, `kubectl apply`, Kubernetes does a rolling update gated by readiness probes, Jenkins waits for `rollout status` and smoke-tests through the Ingress; on failure it runs `rollout undo`. |
| G2 ★ | Why k3s on EC2 instead of EKS? | Cost (no \~$0.10/h control plane fee), it gives Ansible a real job, and k3d locally runs the same distribution. Trade-off: I own control-plane upgrades and HA; for production I would choose EKS. |
| G3 | How does a request reach a pod on AWS? | Browser → ALB :80 → target group on NodePort 30080 of every node → ingress-nginx pod → matches path in the Ingress → ClusterIP Service → a Ready pod. |
| G4 | Which part of the project removes downtime? | Rolling updates with `maxUnavailable: 0` + readiness probes, at least 2 replicas, HPA for load, ALB health checks across nodes, and automatic rollback. |
| G5 | What is the difference between Terraform and Ansible here? | Terraform provisions (creates the infrastructure: VPC, EC2, RDS, S3, ALB) and tracks it in state. Ansible configures what exists (packages, k3s, Helm releases, secrets). Declarative-with-state vs procedural-but-idempotent. |
| G6 | Where are the secrets and how do they flow? | Jenkins credentials store (Docker Hub token, AWS keys, DB password) → env vars in the job → Terraform variable / Ansible extra var → Kubernetes Secret. Never in Git; `.gitignore` covers state, keys, `.env`, kubeconfig. Locally, Ansible Vault. |
| G7 | How do you make sure AWS doesn't cost you money after the demo? | A destroy job (manual + nightly cron), cost tags, a $10 Budget alert, no NAT gateway, `force_destroy` on S3 and `skip_final_snapshot` on RDS so destroy never blocks. |

### Docker (Part 1)

| # | Question | Answer |
| --- | --- | --- |
| D1 ★ | Image vs container? | An image is a read-only template made of layers; a container is a running instance of it with its own writable layer, process and network namespace. |
| D2 ★ | Why multi-stage builds? | Build tools stay in the first stage; the final image carries only runtime files → smaller, faster to pull, smaller attack surface. |
| D3 | Why copy `requirements.txt` before the code? | Layer caching: dependencies are reinstalled only when that file changes, not on every code change. |
| D4 | Why run as non-root? | If the app is compromised, the attacker is not root inside the container, which limits damage and container-escape risk. |
| D5 | `CMD` vs `ENTRYPOINT`? | `ENTRYPOINT` is the fixed executable; `CMD` gives default arguments (or the default command) that `docker run` can override. |
| D6 | Why not deploy the `latest` tag? | It's mutable: you can't tell what's running and can't roll back to it. A Git-SHA tag is traceable and immutable. |
| D7 | How do containers in compose find each other? | Compose creates a network with built-in DNS; the service name (`db`, `search`) resolves to the container IP(s). |
| D8 | `depends_on` vs `condition: service_healthy`? | Plain `depends_on` only orders start-up; with `service_healthy` compose waits for the dependency's health check to pass. |
| D9 | Volume vs bind mount? | A named volume is managed by Docker (used for Postgres data); a bind mount maps a host path (used for `init.sql`, config). |

### Nginx (Part 2)

| # | Question | Answer |
| --- | --- | --- |
| N1 ★ | Reverse proxy vs forward proxy? | A reverse proxy sits in front of servers and receives client traffic for them; a forward proxy sits in front of clients and sends their traffic out. |
| N2 | What does the trailing slash in `proxy_pass http://search_up/;` do? | It replaces the matched location prefix, so `/api/search/products` reaches the service as `/products`. |
| N3 | Why set `X-Forwarded-For`? | So the backend sees the real client IP instead of the proxy's IP (logging, rate limits). |
| N4 | You scaled search to 3 but Nginx still hits one container. Why? | Nginx resolves upstream names once at start-up. Restart/reload Nginx after scaling, or use a `resolver` with a variable in `proxy_pass` for runtime DNS. |
| N5 | Nginx, ingress-nginx and ALB — why three layers? | ALB = AWS entry point, TLS/health checks across nodes; ingress-nginx = path routing inside the cluster defined in Kubernetes objects; plain Nginx = the same role in the docker-compose environment. |
| N6 | How does `limit_req` work? | Leaky-bucket per key (client IP): requests over the rate are delayed or rejected (503) beyond the `burst`. |

### Kubernetes (Part 3)

| # | Question | Answer |
| --- | --- | --- |
| K1 ★ | Liveness vs readiness probe? | Liveness failure → kubelet restarts the container. Readiness failure → pod removed from Service endpoints, no traffic, no restart. That's why `/health` is liveness and `/ready` (DB check) is readiness. |
| K2 ★ | How does the HPA decide how many pods? | Every \~15 s it reads CPU from metrics-server: desired = ceil(current replicas × current utilisation / target). Utilisation is measured against the pod's CPU **request**, so requests are mandatory. Scale-down waits a 5-min stabilisation window. |
| K3 ★ | Deployment vs StatefulSet? | Deployment pods are interchangeable; StatefulSet gives stable names (`db-0`), ordered start-up and a PVC per pod — used for Postgres locally. |
| K4 | ConfigMap vs Secret? | Both inject config; Secrets are base64-encoded (not encrypted by default), can be RBAC-restricted and encrypted at rest. Passwords go in Secrets. |
| K5 | Service types? | ClusterIP (internal), NodePort (port on every node — the ALB target), LoadBalancer (asks the cloud for an LB), ExternalName (DNS CNAME — used to point `db` at RDS). |
| K6 | What do `maxSurge: 1, maxUnavailable: 0` mean? | During an update Kubernetes may add 1 extra pod but never drop below the desired count, so capacity never decreases. |
| K7 | Why Kustomize overlays? | One base of manifests, small patches per environment (local Postgres vs RDS, replica counts, image tags), no copy-paste. |
| K8 | A pod is `CrashLoopBackOff`. What do you do? | `kubectl describe pod` (events), `kubectl logs --previous`, check env/Secret, probes, resources (OOMKilled), image tag. |
| K9 | What is an Ingress controller? | The Ingress object is only rules; the controller (ingress-nginx) is the pod that reads them and actually proxies traffic. |

### Monitoring (Part 4)

| # | Question | Answer |
| --- | --- | --- |
| M1 ★ | Push vs pull monitoring? Which is Prometheus? | Prometheus pulls: it scrapes `/metrics` on targets at an interval. Short-lived jobs can push via Pushgateway. |
| M2 ★ | What are the golden signals? | Latency, traffic, errors, saturation — one panel each on the Golden Signals dashboard. |
| M3 | Counter vs gauge vs histogram? | Counter only goes up (requests); gauge goes up and down (memory, replicas); histogram counts observations in buckets (latency) so you can compute percentiles. |
| M4 | Why `rate()` on a counter? | The raw counter is a running total that resets on restart; `rate()` gives per-second increase and handles resets. |
| M5 | How does Prometheus find the shop pods? | The Prometheus Operator watches `ServiceMonitor` objects; ours selects Services labelled `app in (web, search, payment)` in namespace `shop` and generates scrape config. |
| M6 | What does `for: 2m` in an alert do? | The condition must stay true for 2 minutes (Pending) before the alert Fires — avoids alerts on brief spikes. |
| M7 | Why dashboards as code? | Reproducible: Grafana pods are disposable; the JSON in Git reloads automatically via the sidecar ConfigMap. |

### Jenkins CI/CD (Part 5)

| # | Question | Answer |
| --- | --- | --- |
| J1 ★ | CI vs continuous delivery vs continuous deployment? | CI: every change is built and tested automatically. Delivery: always deployable, release is a manual click. Deployment: every green change goes to production automatically — our pipeline does this. |
| J2 ★ | Declarative vs scripted pipeline? | Declarative has a fixed structure (`pipeline { agent stages post }`), easier to read and validate; scripted is free Groovy. We use declarative with small `script {}` blocks. |
| J3 | How does Jenkins build Docker images while running in a container? | The host's Docker socket is mounted, so the docker CLI in Jenkins talks to Docker Desktop (“Docker outside of Docker”). Trade-off: whoever controls Jenkins controls the Docker host. |
| J4 | Why poll SCM instead of a webhook? | Jenkins runs on a laptop behind NAT, so GitHub can't reach it; a tunnel (ngrok) or a public Jenkins would allow webhooks. |
| J5 | What does “build once, deploy many” mean here? | The same SHA-tagged image is promoted to local and AWS; we never rebuild per environment, only change config via overlays. |
| J6 | How are credentials kept out of logs? | `withCredentials` injects them as env vars and Jenkins masks their values in console output. |
| J7 | What does the `post` section do? | Runs after the stages based on result (`always`, `success`, `failure`); ours triggers rollback on failure. |

### Rollback (Part 6)

| # | Question | Answer |
| --- | --- | --- |
| R1 ★ | How does `kubectl rollout undo` work? | Each Deployment change creates a new ReplicaSet; old ones are kept (`revisionHistoryLimit`). Undo scales the previous ReplicaSet back up and the current one down — a rolling update in reverse. |
| R2 ★ | Rolling vs blue/green vs canary? | Rolling replaces pods gradually; blue/green runs two full versions and switches traffic at once (instant rollback, double cost); canary sends a small % of traffic to the new version first. |
| R3 | What if the database schema changed? Can you still roll back? | Only if changes are backward compatible: expand (add columns), deploy code, then contract later. Otherwise you need a migration down-script or a restore from RDS snapshot. |
| R4 | What happens if the very first deploy fails? | There is no previous revision, so `rollout undo` has nothing to return to; the readiness gate still keeps broken pods out of traffic. |
| R5 | Rollback vs roll-forward? | Rollback returns to the last good version; roll-forward ships a fix quickly. Rollback first when users are affected, then fix forward. |
| R6 | How would you roll back infrastructure? | `git revert` the Terraform change and apply; state bucket versioning recovers a corrupted state; RDS snapshots recover data. |

### Terraform (Part 7)

| # | Question | Answer |
| --- | --- | --- |
| T1 ★ | What is the state file and why remote? | It maps your code to real resource IDs. Remote in S3 (versioned, encrypted) so Jenkins and you share one truth, it survives a laptop loss, and locking prevents two applies at once. |
| T2 ★ | `count` vs `for_each`? | `count` indexes by number, so removing an item in the middle shifts and recreates others; `for_each` keys by name, so only that item changes. |
| T3 ★ | What does `terraform plan` do? | Refreshes state, compares desired config with real infrastructure and shows the create/update/destroy actions without making them. |
| T4 | What is a `dynamic` block? | Generates repeated nested blocks (like SG `ingress`) from a collection, so rules come from variables instead of copy-paste. |
| T5 | How does Terraform know to create the VPC before the EC2? | Implicit dependencies from references (`module.network.vpc_id`) build a graph; `depends_on` only when there's no reference. |
| T6 | What is drift and how do you detect it? | Real infrastructure changed outside Terraform; `terraform plan -refresh-only` shows it. |
| T7 | Why `-out=tfplan` in Jenkins? | Apply executes exactly the reviewed plan, not a new one that may differ. |
| T8 | Workspaces vs separate folders per environment? | Workspaces share code with separate state (good for identical envs); folders allow different code per env. We use one folder + workspace + tfvars. |
| T9 | How did you bootstrap the state bucket? | A separate `bootstrap` config with local state creates it once; it's never destroyed by the demo job. |
| T10 | Why is RDS in private subnets with no NAT? | RDS needs no internet; its security group allows 5432 only from the node SG. No NAT saves \~$0.05/h plus data costs. |

### Ansible (Part 8)

| # | Question | Answer |
| --- | --- | --- |
| A1 ★ | What does idempotent mean, and how did you prove it? | Running it again leaves the system unchanged. Second `site.yml` run shows `changed=0`; shell tasks use `creates:`. |
| A2 ★ | Why is Ansible agentless? | It connects over SSH and runs Python modules on the target; nothing to install or keep running on nodes. |
| A3 | Playbook vs role? | A playbook maps hosts to tasks/roles; a role is a reusable package of tasks, handlers, templates, defaults in a standard layout. |
| A4 | How do agents get the k3s token? | The server play reads it with `slurp`, stores it as a fact; agents read it via `hostvars[groups['server'][0]]`. |
| A5 | What is a handler? | A task that runs only when notified by a changed task, once at the end of the play (e.g., restart a service after config change). |
| A6 | Variable precedence — which wins? | Extra vars (`-e`) win over almost everything; then role/play vars; group\_vars/host\_vars sit below; role defaults lowest. |
| A7 | How do you keep the DB password secret? | Jenkins credential passed as an extra var in CI; Ansible Vault file for manual runs; `no_log: true` on tasks that use it. |
