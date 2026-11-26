# Build progress

Each part is built on its own branch (`feat/part-N-...`) and merged to `main` through a pull request.

| Part | Branch | Status |
|---|---|---|
| 0 Setup + repo | feat/part-0-setup | written, validated statically; live run pending |
| 1 Docker | feat/part-1-docker | written, validated statically; live run pending |
| 2 Nginx | feat/part-2-nginx | written, validated statically; live run pending |
| 3 Kubernetes + HPA | feat/part-3-kubernetes | written, validated statically; live run pending |
| 4 Monitoring | feat/part-4-monitoring | written, validated statically; live run pending |
| 5 Jenkins CI/CD | feat/part-5-jenkins | written, validated statically; live run pending |
| 6 Rollback | feat/part-6-rollback | written, validated statically; live run pending |
| 7 Terraform | feat/part-7-terraform | written, validated statically; live run pending |
| 8 Ansible | feat/part-8-ansible | written, validated statically; live run pending |
| 9 AWS demo | feat/part-9-demo | written, validated statically; live run pending |

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
  `db-credentials` created by `local-k8s-up.sh` from `docker/.env` (so CI re-deploys never change it), HPA max 4, images `local/ecom-*:dev` imported into k3d.
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

## Part 5 - Jenkins CI/CD

- `jenkins/Dockerfile`: Jenkins LTS (JDK 21) + docker CLI/compose/buildx, kubectl, kustomize, helm,
  terraform (latest), aws cli v2, ansible (venv, + kubernetes.core), hey, hadolint; plugins from
  `plugins.txt`; setup wizard off; Configuration as Code from `jenkins/casc/`.
- `jenkins/casc/jenkins.yaml`: admin user, executors, credentials `dockerhub`, `aws-creds`,
  `db-password` from environment variables (`jenkins/.env`, git-ignored; see `.env.example`).
- `jenkins/casc/jobs.yaml`: Job DSL for `shop-pipeline` (poll SCM every 2 min), `shop-rollback`,
  `infra-apply`, `infra-destroy` (nightly 23:00 Africa/Cairo).
- `jenkins/run-jenkins.sh`: builds the image, runs it on the `k3d-shop` network with the Docker socket,
  copies a kubeconfig for the local cluster (server `k3d-shop-serverlb:6443`) into
  `jenkins_home/kube/local.yaml`. The AWS kubeconfig is written to `kube/aws.yaml` by Ansible.
- `jenkins/Jenkinsfile` stages: Checkout (tag = 8-char Git SHA) -> Lint (hadolint, config sync,
  kustomize build, py_compile) -> Build (compose build, images `docker.io/<user>/ecom-*:<sha>`) -> Test
  (compose smoke test) -> Push -> Deploy (`kustomize edit set image`, `kubectl apply -k`) -> Verify
  (rollout status + `jenkins/scripts/smoke-test.sh` through Nginx).
- Deviation from the plan: kubeconfigs are files in the Jenkins volume instead of credentials, because
  the AWS server IP changes on every apply.
- The local DB secret is now created by `local-k8s-up.sh` instead of kustomize, so a Jenkins deploy can
  never change the password Postgres was initialised with.

## Part 6 - Automated rollback

- Layer 1 (Kubernetes): rolling updates with `maxUnavailable: 0` + readiness probes; a release whose pods
  never get Ready never receives traffic.
- Layer 2 (pipeline): `rollout status --timeout=150s` and the smoke test in Verify; on failure after a
  deploy, `post { failure }` runs `jenkins/scripts/rollback.sh` (`kubectl rollout undo` for each service,
  skipping services with no previous revision) and re-runs the smoke test.
- Layer 3 (metrics): `jenkins/scripts/metric-gate.sh` queries Prometheus through the API server proxy
  for 120 s while Verify sends light traffic; 5xx ratio above 5% fails the build -> rollback.
- Layer 4 (manual): `shop-rollback` job (`jenkins/Jenkinsfile.rollback`): service + optional revision.
- Layer 5 (infra): S3 state versioning + `git revert` + apply (Part 7).
- Demo without Jenkins: `scripts/rollback-demo.sh` (bad release held back, zero non-200 responses, undo).
- Demo with Jenkins: commit `FAIL_READY: "true"` in `k8s/base/web.yaml` (layer 2) or `ERROR_RATE: "0.3"`
  in `k8s/base/payment.yaml` (layer 3), push, watch the build roll back, then `git revert` the commit.

## Part 7 - Terraform

- `terraform/bootstrap` + `bootstrap.sh`: state bucket `ecommerce-devops-tfstate-<account id>` (versioning,
  AES256, public access block, 30-day expiry of old versions), created only if missing.
- Modules `network`, `compute`, `database`, `storage`, `loadbalancer`; root `envs/demo` with partial S3
  backend (`use_lockfile = true`), `default_tags`, validation on `admin_cidr`, `agent_count`, `db_password`,
  `project`; `enable_rds` toggles the database module with `count`; `local_file` + `templatefile` write
  `ansible/inventory/aws.ini` and `ansible/group_vars/all/tf.yml`.
- Security groups: node SG rules are separate resources (the loadbalancer module adds the ALB -> 30080
  rule; inline + separate rules on one group would fight); the ALB SG demonstrates a `dynamic` block.
- Product images: `assets/product-images/*.svg` uploaded to S3; `app/db/init.sql` now references `.svg`.
- `jenkins/Jenkinsfile.infra`: one file for `infra-apply` and `infra-destroy` (picked by job name):
  SSH key + your public IP -> bootstrap -> init -> plan (+ cost note) -> approval (manual destroy only;
  the nightly timer skips it) -> apply -> Ansible -> `shop-pipeline TARGET_ENV=aws`; destroy ends by counting
  leftover EC2/RDS/ALB.
- Verified here: `fmt` and `validate` pass for `bootstrap` and `envs/demo` (OpenTofu 1.10 with
  hashicorp/aws 5.100). `plan`/`apply` need Kareem's AWS account.
- Provider pinned to `>= 5.70, < 6.0` (the version validated); upgrading to v6 is a separate task.

## Part 8 - Ansible

- `ansible/ansible.cfg`, `requirements.yml` (kubernetes.core), `group_vars/all/main.yml` (k3s channel,
  timezone, kubeconfig path), `vault.yml.example` (Ansible Vault for manual runs).
- `wait-for-hosts.yml`: waits for SSH and cloud-init on new instances.
- `site.yml` plays: `common` (packages, timezone, sysctl + br_netfilter, SSH password login off, automatic
  security updates) -> `k3s_server` (install with `--disable traefik --tls-san <public ip>`, token shared as
  a host fact, kubeconfig rewritten to the public IP and written to `kubeconfig_out`) -> `k3s_agent` (join
  over the private IP) -> on the controller via the Kubernetes API: `platform` (wait for all nodes Ready,
  Grafana admin secret once, kube-prometheus-stack with `monitoring/values.yaml`, shop monitoring objects
  via the kustomize lookup) and `app_config` (`db` ExternalName -> RDS, `db-credentials` with
  `sslmode=require`, `shop-env` with the S3 image URL).
- Idempotency: shell installs use `creates:`, checks use `changed_when: false`, secrets are created only
  when missing; a second run should report `changed=0` on the nodes.
- `k8s/overlays/aws/db-init-job.yaml`: Job that seeds RDS with `init.sql` (idempotent) using the
  `ecom-db` image's psql.
- Not verified here: no ansible available in this workspace (package downloads blocked). YAML parses;
  first real run happens with the AWS apply.

## Part 9 - Demo

- `docs/DEMO.md`: preparation checklist, 10-step script with timings, backup plan, after-demo checks.
- Jenkins Lint stage also runs `terraform fmt -check`.

## What still needs Kareem / a live machine

1. Push access for Claude to `DevOps-team2-star/Automated-E-Commerce-Deployment-Platform` (Claude GitHub App),
   or push the branches yourself (see below).
2. First live run on the PC: `scripts/install-tools.sh`, compose smoke test, `local-k8s-up.sh`,
   `monitoring/install.sh`, Jenkins.
3. Docker Hub user + access token, AWS IAM keys and an RDS password in `jenkins/.env`.
4. First `infra-apply` on AWS, then `infra-destroy`.

## Local AWS emulator + local registry (real AWS and Docker Hub postponed)

Real AWS deployment is postponed. Until then the AWS side is tested against a local emulator, and the
CI/CD pipeline works without any account.

- **Emulator choice.** LocalStack now needs a (free Hobby) account + auth token since March 2026, and its
  free tier has no RDS and no ELBv2. **MiniStack** (MIT, no account) is the default; LocalStack still works
  (`EMULATOR=localstack`, with `ENABLE_RDS=false ENABLE_ALB=false`). Both listen on port 4566.
- `scripts/emulator-up.sh`: starts the emulator as container `aws-emulator` on `localhost:4566`, joined to
  the `k3d-shop` network (Jenkins reaches it at `http://aws-emulator:4566`), with the Docker socket so
  emulated RDS can start a real Postgres container.
- Terraform (same code as real AWS):
  - `aws_endpoint` variable: empty = real AWS; set = provider `endpoints` (dynamic block), path-style S3
    and skipped credential/account checks.
  - `ami_id` variable skips the Ubuntu AMI lookup (emulators have their own fake AMIs).
  - `enable_alb` toggles the load balancer module (`count`), like `enable_rds`.
  - `terraform/bootstrap.sh` keeps the emulator's bootstrap state in a separate workspace (`emulator`).
- `terraform/emulator.sh [cycle|apply|destroy]`: bootstrap the state bucket inside the emulator, `init` with
  an S3 backend pointing at the emulator, plan/apply, list what was created (VPC, subnets, EC2, S3 images,
  RDS, ALB), show outputs and the generated Ansible inventory, then destroy (`cycle`). Uses `-lock=false`
  because emulators may not implement S3 conditional writes.
- Jenkins job `infra-emulator` (`jenkins/Jenkinsfile.emulator`): fmt + validate + `emulator.sh`.
- **Limit:** emulated EC2 instances are API records, not servers. Ansible and k3s are therefore exercised on
  real AWS later; the `platform`/`app_config` logic is the same as what runs on the local k3d cluster.
- **Local registry.** `scripts/local-k8s-up.sh` creates a k3d registry (push `localhost:5050`, pull
  `k3d-registry.localhost:5050`) and attaches it to the cluster. When the `dockerhub` credential is not set,
  `shop-pipeline` pushes there instead of Docker Hub (local deploys only; AWS still needs Docker Hub).

Run it:

```bash
./scripts/local-k8s-up.sh          # cluster + registry (first time)
./scripts/emulator-up.sh           # MiniStack on :4566
./terraform/emulator.sh cycle      # Terraform apply -> verify -> destroy against the emulator
```

## Fix: tool install on Ubuntu 26.04 (first live run)

- First run of `scripts/install-tools.sh` on Kareem's WSL (Ubuntu 26.04 "resolute") stopped at `hey`: its
  S3 download failed TLS verification. `hey` now comes from the Ubuntu/Debian package (also in the Jenkins
  image), and the optional tools (`hey`, `hadolint`) print a warning instead of aborting the script.
- Installed on that run: jq, pipx, unzip, k3d, helm 3.22.1, kustomize 5.8.3, terraform 1.17.2,
  ansible 15.0.0 (+ kubernetes lib), aws cli v2. kubectl was already present.

## Part 0 confirmed on Kareem's PC (2026-11-26)

`scripts/check-tools.sh` ran clean after a fresh `git clone` into `~/automated-e-commerce-deployment-platform`:
docker 29.7.2, compose 5.5.0, git 2.53.0, kubectl 1.36.1, k3d 5.9.0, helm 3.22.1, kustomize 5.8.3,
terraform 1.17.2, ansible core 2.22.0, aws-cli 2.42.2, jq 1.8.1, hey, hadolint 2.15.1 — all OK.
Part 0 marked ✅ in docs/HANDS-ON-GUIDE.md. Added docs/explain/part-1.md (Docker Compose stack explained).
