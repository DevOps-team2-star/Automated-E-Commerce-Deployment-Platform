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

**Status: 🟡 built + auto-verified by me — needs your manual confirmation**

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

**Status: 🟡 built + auto-verified by me (compose-smoke-test.sh passed on your PC) — needs YOUR eyes on it in a browser**

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

**Status: ⬜ waiting for Part 1 confirmation first**

### What will be built (next)
- `scripts/nginx-demo.sh` — shows the routing table, load-balances across 3 copies of the search service, and demonstrates the payment endpoint rejecting too-many-requests (HTTP 429)

### Code on GitHub
- Will be linked here once built: `nginx/default.conf`, `nginx/Dockerfile`, `scripts/nginx-demo.sh` (every part from now on gets real GitHub links added here, not just file names)

### How you'll test it
Script output pasted here, plus I'll ask you to refresh `http://localhost/api/search/products` a few times and watch different container names answer in the logs.

**→ Not ready to test yet. Confirm Part 1 first.**

---

## Part 3 — Kubernetes (k3d cluster "shop" + local registry)
**Status: ⬜ not started**

## Part 4 — Monitoring (Prometheus + Grafana)
**Status: ⬜ not started**

## Part 5 — Jenkins (CI/CD)
**Status: ⬜ not started**
> Note: Jenkins' own web UI normally lives at **http://localhost:8080** (that is a Jenkins URL like `/view/all/`, not part of our shop app). We have not started Jenkins yet, so nothing is there right now — that's expected, not a bug.

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
