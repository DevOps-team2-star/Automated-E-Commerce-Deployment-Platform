# Hands-On Guide — خطوة بخطوة

This file is our single learning log. It starts near-empty and grows one part at a time.
For every part the pattern is always the same:

1. **I build it** (code, scripts, configs) and push it to GitHub.
2. **I test it myself** (automated: curl, kubectl, scripts) and paste the evidence here.
3. **You test it manually** on your own PC, following the exact steps I give you — **with a direct GitHub link to every file involved**, so you can open and read the real code while you test it, not just trust that it works.
4. **You confirm** ("✅ works" or "❌ problem: ...") in chat.
5. Only after your confirmation do we move to the next part.

No part is marked DONE until step 4 happens. Coded ≠ Done.

Repo: https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform (branch `main` unless noted)

### Every part gets exactly 3 things (in chat, each time a part is tackled)
1. **An infographic/diagram** of that part — shown inline in chat, icons included.
2. **Manual test steps** — commands/clicks for you to run yourself on your PC.
3. **Code review** — a plain-language walkthrough of the real files, saved to `docs/explain/part-N.md` with live GitHub links, so you can revisit it later to memorize everything without re-asking.

This file only tracks status + links; the diagrams live in the chat history and the file-by-file explanations live in `docs/explain/`.

Legend: ⬜ not started · 🟡 built, waiting for your manual test · ✅ confirmed by you

---

## Part 0 — Machine setup (WSL2, Docker, tools, Git repo)

**Status: ✅ confirmed 2026-11-26 — all tools OK on Kareem's PC (docker 29.7.2, kubectl 1.36.1, k3d 5.9.0, helm 3.22.1, kustomize 5.8.3, terraform 1.17.2, ansible core 2.22.0, aws-cli 2.42.2, hey, hadolint)**

- Infographic: shown in chat ✅
- Manual test steps: below ✅
- Code review: [`docs/explain/part-0.md`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/docs/explain/part-0.md) ✅

### What was built
- `scripts/install-tools.sh` — installs docker, kubectl, k3d, helm, kustomize, terraform, ansible, aws-cli, hey, hadolint inside WSL2 Ubuntu
- `scripts/check-tools.sh` — prints the version of every tool so we can see what's installed
- The GitHub repo itself, with branches per part

### Code on GitHub (open these while you test)
- [`scripts/install-tools.sh`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/scripts/install-tools.sh) — read top to bottom: it's one `apt`/official-installer line per tool, each wrapped so one failure (like `hey`) doesn't stop the rest
- [`scripts/check-tools.sh`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/scripts/check-tools.sh) — just runs `<tool> --version` for every tool in a loop
- [`CLAUDE.md`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/CLAUDE.md) — the project's fixed decisions (machine, cluster name, safety rules) — worth skimming once
- [Commit that fixed the `hey` install (PR #12)](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/pull/12/files) — real example of a bug you hit and how it got fixed

### How to test it yourself (5 min)
Open your WSL2 Ubuntu terminal in the project folder and run:
```bash
cd ~/automated-e-commerce-deployment-platform   # or wherever you cloned it
git pull
bash scripts/check-tools.sh
```

### Acceptance criteria
- [ ] `docker --version` shows a version (Docker Desktop is running)
- [ ] `kubectl version --client` shows a version
- [ ] `k3d version` shows a version
- [ ] `terraform version` or `tofu version` shows a version
- [ ] `ansible --version` shows a version
- [ ] no "command not found" errors

**→ Paste the output here in chat. I will mark this ✅ once you confirm.**

---

## Part 1 — Docker: build the 4 services + database

**Status: ✅ confirmed 2026-11-26 — storefront loaded on `http://localhost:8081`, real purchase succeeded (Order 7, $79.90) — needed `NGINX_PORT=8081` since port 80 was taken on Windows**

- Infographic: shown in chat ✅
- Manual test steps: above ✅
- Code review: [`docs/explain/part-1.md`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/docs/explain/part-1.md) ✅

### What was built
- `app/web`, `app/search`, `app/payment` — the 3 Flask services (Dockerfile each, non-root, healthcheck)
- `app/db` — Postgres 16 with seed data (12 demo products) baked in
- `docker/docker-compose.yml` — runs all of them together on your machine

### Code on GitHub (open these while you test)
- [`docker/docker-compose.yml`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/docker/docker-compose.yml) — the file that defines all 5 containers (db, search, payment, web, nginx) and how they talk to each other
- [`app/web/Dockerfile`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/app/web/Dockerfile) / [`app/search/Dockerfile`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/app/search/Dockerfile) / [`app/payment/Dockerfile`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/app/payment/Dockerfile) — each builds a small non-root image; compare them, they're nearly identical
- [`app/web/app.py`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/app/web/app.py) — the actual Flask code serving the storefront (provided app code, not something I wrote — see `CLAUDE.md`)
- [`app/db/init.sql`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/app/db/init.sql) — the schema + the 12 seed products you'll see in the browser
- [`scripts/compose-smoke-test.sh`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/scripts/compose-smoke-test.sh) — the exact script that already passed 7/7 on your PC; read it to see what "passed" actually checked

### What I already tested (automated)
You ran `scripts/compose-smoke-test.sh` and it printed **7/7 checks PASSED**, including a real purchase (`order_id=1`, `$79.90`) and a declined test card (`402`).

### How to test it yourself now — SEE it with your own eyes
```bash
cd ~/automated-e-commerce-deployment-platform
docker compose -f docker/docker-compose.yml up -d --build
docker compose -f docker/docker-compose.yml ps
```
Wait until all 4 services show "healthy", then open in your Windows browser:
- `http://localhost` → the shop storefront (product grid)
- `http://localhost/api/search/products` → raw JSON of products
- `http://localhost/api/payment/orders` → raw JSON (empty list until you buy something)

> If port 80 is already used on Windows, use `http://localhost:8081` instead (set `NGINX_PORT=8081` in `docker/.env` first).

To stop everything: `docker compose -f docker/docker-compose.yml down`

### Acceptance criteria
- [ ] `docker compose ps` shows web, search, payment, db, nginx all "Up (healthy)"
- [ ] `http://localhost` shows the storefront with product images and titles
- [ ] clicking a product and buying it works, and shows a success message
- [ ] `http://localhost/api/search/products` returns a JSON list (not an error)

**→ Tell me "✅ Part 1 works" or paste what you saw instead.**

---

## Part 2 — Nginx: one entry point, load balancing, rate limiting

**Status: ✅ confirmed 2026-11-26 — routing all 200s, load balanced across 3 search IPs (25/4/3 split), rate limit rejected 38/60 with HTTP 429**

- Infographic: shown in chat ✅
- Manual test steps: below ✅
- Code review: [`docs/explain/part-2.md`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/docs/explain/part-2.md) ✅

### Code on GitHub
- [`nginx/default.conf`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/nginx/default.conf) — routing rules, rate limit, health/status endpoints
- [`scripts/nginx-demo.sh`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/scripts/nginx-demo.sh) — the 3-part demo (routing, load balancing, rate limit)

### How to test it yourself
Your stack from Part 1 is already running on port 8081:
```bash
cd ~/automated-e-commerce-deployment-platform
export NGINX_PORT=8081
bash scripts/nginx-demo.sh
```

### Acceptance criteria
- [ ] Routing section: every path returns HTTP 200 (except maybe one 404, that's fine)
- [ ] Load balancing section: the `upstream=` counts are spread across more than one IP, not all on one
- [ ] Rate limit section: you see a mix of HTTP 200 and HTTP 429 in the 60-request burst

**→ Paste the full output here.**

---

## Part 3 — Kubernetes (k3d cluster "shop" + local registry)

**Status: 🟡 cluster already running (46h old, from earlier work) — port was fixed after a clash, needs re-test**

- Infographic: shown in chat ✅
- Manual test steps: below ✅
- Code review: [`docs/explain/part-3.md`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/docs/explain/part-3.md) ✅

> ⚠️ **Port fix (2026-11-26):** the cluster originally used `localhost:8080`, but Kareem has an
> unrelated, pre-existing Jenkins already running on that exact port on his machine (not ours —
> seen at `http://localhost:8080` showing a vanilla "Welcome to Jenkins!" with no jobs, nothing to
> do with this project). That's why `curl .../api/search/products | jq` failed with a JSON parse
> error — the request was actually hitting that other Jenkins' HTML page, not our cluster.
> `scripts/local-k8s-up.sh` now defaults to **`localhost:8888`** instead (override with `LB_PORT=`).
> The cluster has to be recreated once to pick up the new port — see test steps below.

### Code on GitHub
- [`scripts/local-k8s-up.sh`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/scripts/local-k8s-up.sh) — creates the cluster, builds/imports images, deploys
- [`k8s/base/web.yaml`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/k8s/base/web.yaml) — Deployment + Service pattern (same shape for search/payment)
- [`k8s/base/hpa.yaml`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/k8s/base/hpa.yaml) — the auto-scaling rules
- [`k8s/overlays/local/`](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/tree/main/k8s/overlays/local) — the local-only Postgres + smaller HPA caps

### How to test it yourself
The existing cluster was created with the old port, so delete it once and recreate on the new port
(this only removes the local k3d cluster container, not your code or images):
```bash
cd ~/automated-e-commerce-deployment-platform
git pull
k3d cluster delete shop
docker compose -f docker/docker-compose.yml down   # free up the images/ports first
bash scripts/local-k8s-up.sh
```
Takes a few minutes. Then:
```bash
kubectl -n shop get pods,svc,hpa
curl -s http://localhost:8888/api/search/products | jq length
```
Open `http://localhost:8888` in your browser — note the new port, not 8080.

### Acceptance criteria
- [ ] `kubectl -n shop get pods` shows all pods `Running` / `1/1` or `2/2` Ready
- [ ] `http://localhost:8888` shows the same storefront
- [ ] `jq length` prints `12`

**→ Paste the output here.**

## Part 4 — Monitoring (Prometheus + Grafana)
**Status: ⬜ not started**

## Part 5 — Jenkins (CI/CD)
**Status: ⬜ not started**
> Note: *our* Jenkins will run on **http://localhost:8090** (`jenkins/run-jenkins.sh`), chosen
> specifically to avoid the unrelated Jenkins already on Kareem's machine at `localhost:8080`
> (see the Part 3 port-fix note above) and the shop's own `localhost:8888` (Part 3).

## Part 6 — Automated rollback
**Status: ⬜ not started**

## Part 7 — Terraform (AWS, tested on the local emulator first)
**Status: ⬜ not started**

## Part 8 — Ansible
**Status: ⬜ not started**

## Part 9 — Full demo rehearsal
**Status: ⬜ not started**

---

## How parts connect (big picture)
```
Part 0 (WSL + tools + repo)
   -> gives us a working machine + place to store code
Part 1 (Docker images: web, search, payment, db)
   -> gives us 4 runnable containers
Part 2 (Nginx)
   -> puts ONE door in front of those 4 containers
Part 3 (Kubernetes)
   -> runs the SAME containers + SAME nginx config, but managed/scaled automatically
Part 4 (Monitoring)
   -> watches Part 3's pods and shows graphs
Part 5 (Jenkins)
   -> automates "build Part 1 images -> deploy to Part 3" on every code change
Part 6 (Rollback)
   -> makes Part 5 undo itself automatically if a deploy breaks things
Part 7 (Terraform) + Part 8 (Ansible)
   -> build a REAL (or emulated) AWS version of Part 3's cluster
Part 9 (Demo)
   -> the 10-minute story that shows all of the above to your instructor
```
