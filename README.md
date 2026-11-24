# Automated E-Commerce Deployment Platform

DevOps Team 2 project.

**Project idea:** The Automated E-Commerce Deployment Platform is an enterprise-grade cloud deployment
solution engineered to eliminate website downtime and simplify complex microservice updates. It
orchestrates the full DevOps lifecycle of a multi-tier e-commerce system (web storefront, database,
payment gateway and search service) by leveraging containerization, Infrastructure as Code (IaC),
continuous automation and dynamic auto-scaling.

**Project members:** Kareem Salah - Hesham Mohamed - Ahmed Refat - Ahmed Mohamed Awaad - Ahmed Osama
**Instructor:** Ahmed Gamil

---

## Architecture

```text
                 GitHub ──poll──> Jenkins (Docker, laptop) ──push──> Docker Hub
                                    │                │
                       deploy local │                │ terraform + ansible + deploy
                                    v                v
   Local: k3d cluster on WSL2                   AWS eu-central-1 (demo only)
   ┌──────────────────────────────┐             ┌──────────────────────────────────┐
   │ Nginx reverse proxy :8080    │             │ ALB :80 -> NodePort 30080         │
   │  ├─ web      (HPA)           │             │ k3s on EC2: Nginx -> web/search/  │
   │  ├─ search   (HPA)           │             │             payment               │
   │  └─ payment                  │             │ RDS PostgreSQL (private subnets)  │
   │ Postgres StatefulSet + PVC   │             │ S3: product images, Terraform     │
   │ Prometheus + Grafana         │             │ state; Prometheus + Grafana       │
   └──────────────────────────────┘             └──────────────────────────────────┘
```

| Deliverable | Where |
|---|---|
| 1. Dockerized microservices | `app/*/Dockerfile`, `docker/docker-compose.yml` |
| 2. CI/CD pipelines | `jenkins/` |
| 3. Kubernetes + auto-scaling | `k8s/base`, `k8s/overlays/{local,aws}` |
| 4. Ansible configuration | `ansible/` |
| 5. Prometheus dashboards | `monitoring/` |
| 6. Nginx reverse proxy | `nginx/` (compose and Kubernetes) |
| 7. Terraform for AWS EC2, RDS, S3, ELB | `terraform/` |
| 8. Automated rollback | `jenkins/Jenkinsfile`, `jenkins/scripts/rollback.sh`, `jenkins/Jenkinsfile.rollback` |
| 9. Git repository | this repo, one branch + PR per part |

The full plan, labs and questions bank are in [`docs/PLAN.md`](docs/PLAN.md). Build progress and
deviations from the plan are recorded in [`docs/PROGRESS.md`](docs/PROGRESS.md).

## Services (provided application code in `app/`)

| Service | Port | Depends on | Env vars | Endpoints |
|---|---|---|---|---|
| web | 8080 | search, payment | `SEARCH_URL`, `PAYMENT_URL`, `IMAGE_BASE_URL`, `FAIL_READY`, `APP_VERSION` | `/`, `POST /buy`, `/health`, `/ready`, `/metrics` |
| search | 8081 | PostgreSQL | `DATABASE_URL`, `CPU_WORK` | `/products`, `/products/<id>`, `/search?q=`, `/health`, `/ready`, `/metrics` |
| payment | 8082 | PostgreSQL | `DATABASE_URL`, `ERROR_RATE` | `POST /pay`, `/orders`, `/health`, `/ready`, `/metrics` |
| db | 5432 | - | `POSTGRES_*` | schema + seed in `app/db/init.sql` |

- `/health` = process alive (liveness). `/ready` = dependencies reachable (readiness).
- Demo switches: `FAIL_READY=true` on web (bad release), `ERROR_RATE=0.3` on payment (5xx errors),
  a card ending in `0000` is declined, `CPU_WORK` adds CPU per search request (HPA demo).

## Quick start (Windows + WSL2 Ubuntu, Docker Desktop with WSL integration)

```bash
./scripts/install-tools.sh          # once: kubectl, k3d, helm, kustomize, terraform, ansible, aws, hey...
./scripts/check-tools.sh

# Part 1-2: docker compose stack behind Nginx -> http://localhost
cp docker/.env.example docker/.env
docker compose -f docker/docker-compose.yml up -d --build

# Part 3-4: local Kubernetes + monitoring -> http://localhost:8080, Grafana http://localhost:3000
./scripts/local-k8s-up.sh
./monitoring/install.sh

# Part 5-6: Jenkins -> http://localhost:8090
./jenkins/run-jenkins.sh
```

AWS (Parts 7-9): Jenkins job `infra-apply` builds everything, `infra-destroy` removes it
(also runs every night at 23:00 Africa/Cairo). See `docs/PROGRESS.md` for the exact steps.
