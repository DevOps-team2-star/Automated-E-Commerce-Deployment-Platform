# Part 5 explained — Jenkins (CI/CD)

## Why this part exists
So far, every deploy has been a human (you) typing commands. CI/CD automates that: push code,
and a pipeline builds it, tests it, and deploys it — the same steps, every time, with no step
skipped because someone was in a hurry.

## File-by-file

### `jenkins/Dockerfile`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/jenkins/Dockerfile)

Jenkins LTS plus every CLI tool the pipeline needs baked directly into the image: `docker` CLI
(not the daemon — see below), `kubectl`, `kustomize`, `helm`, `terraform`, `aws` CLI, `hadolint`,
and `ansible` in a Python venv. Without this, every pipeline run would need to install tools on the
fly, which is slow and can silently pick up a different tool version each time.

### `jenkins/run-jenkins.sh`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/jenkins/run-jenkins.sh)

- Builds the custom image, then runs it with **the host's Docker socket mounted**
  (`-v /var/run/docker.sock:/var/run/docker.sock`) — this is "Docker-outside-of-Docker": Jenkins
  doesn't run its own nested Docker daemon, it just uses the `docker` CLI to talk to your laptop's
  *existing* Docker Desktop. That's how the pipeline can build and run containers from inside a
  container.
- Joins the `k3d-shop` Docker network, so Jenkins can reach the cluster's internal load balancer
  address directly (`k3d-shop-serverlb`) without going through your laptop's published ports.
- Writes a kubeconfig for the local cluster into the `jenkins_home` volume — this is how pipeline
  steps like `kubectl apply` know which cluster to talk to, without any kubeconfig living in the
  Git repo (which would be a secret).
- Runs on port **8090**, not 8080 — deliberately chosen from the start to avoid any other Jenkins
  you might already have running.

### `jenkins/casc/jobs.yaml` + `jenkins/casc/jenkins.yaml`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/jenkins/casc/jobs.yaml)

"Configuration as Code" (JCasC) — instead of clicking through Jenkins' UI to create the admin user,
credentials, and 4 pipeline jobs by hand (which nobody could reproduce from a README), these two
YAML files declare all of it. On first boot, Jenkins reads them and provisions itself identically
every time the container is rebuilt.

### `jenkins/Jenkinsfile` (the `shop-pipeline` job)
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/jenkins/Jenkinsfile)

A declarative pipeline with 7 stages, run in order:
1. **Checkout** — pulls the code, computes `GIT_SHA` (short commit hash) to use as the image tag —
   this is the "never use `latest`" rule from `CLAUDE.md` in action: every build gets a traceable,
   unique tag. Also decides here whether to push to Docker Hub or the local registry, based on
   whether Docker Hub credentials exist yet (currently postponed, so it uses the local registry).
2. **Lint** — runs `hadolint` on every Dockerfile, validates both Kustomize overlays build cleanly,
   byte-compiles the Python app files, and checks Terraform formatting — catches mistakes before
   spending time building anything.
3. **Build** — the same `docker compose build` command you've been running by hand.
4. **Test** — runs the exact `compose-smoke-test.sh` from Part 1 (can be skipped via a pipeline
   parameter for faster iteration, but runs by default).
5. **Push** — pushes the tagged images to whichever registry was decided in step 1.
6. **Deploy** — uses `kustomize edit set image` to point the chosen overlay at this build's exact
   image tag, then `kubectl apply -k` — this is the same manual step from Part 3, now automated and
   tag-pinned.
7. **Verify** — waits for the rollout to finish, runs a smoke test against the live URL, *and* (the
   interesting part) fires light payment traffic for 2 minutes while watching the 5xx error ratio
   via `metric-gate.sh` — this is rollback safety layer 3 from `CLAUDE.md`: if the new version is
   quietly broken (passes health checks but errors on real requests), this catches it.
- `post { failure { ... } }` — if anything above fails *after* a deploy already happened, it
  automatically runs `rollback.sh` (rollback layer 2) rather than leaving a broken version live.

## How to demo this part
```bash
cd ~/automated-e-commerce-deployment-platform
cp jenkins/.env.example jenkins/.env   # edit JENKINS_ADMIN_PASSWORD
bash jenkins/run-jenkins.sh
```
Open `http://localhost:8090` → run `shop-pipeline` with `TARGET_ENV=local` → watch all 7 stages
turn green.

## 5 questions an instructor might ask

**1. Why mount the host's Docker socket instead of running Docker-in-Docker (a nested daemon)?**
Docker-outside-of-Docker is simpler and faster — it reuses the one Docker daemon already running on
the laptop instead of starting a second, isolated one inside the Jenkins container, and avoids
known DinD stability/security quirks (privileged containers, storage driver issues).

**2. Why tag images with the Git SHA instead of `latest` or a version number?**
`latest` is not unique or traceable — you can't tell which code is actually running, and a rollback
has nothing specific to roll back to. The Git SHA ties every running image back to an exact commit.

**3. What's the point of Configuration as Code (JCasC) instead of just setting Jenkins up through
the UI once?**
Reproducibility — if Jenkins' container or volume is ever lost, `docker build && run` recreates an
identical setup (same jobs, same credentials wiring) with zero manual reclicking, and the
configuration itself is reviewable in a pull request like any other code.

**4. Why does the pipeline run a Lint stage before Build, when linting doesn't test behavior?**
It's cheap and fast — catching a bad Dockerfile instruction or an invalid Kustomize overlay in
seconds is better than discovering it minutes later after a full image build.

**5. What exactly does "rollback" mean here, mechanically?**
`rollback.sh` runs `kubectl rollout undo`, which tells Kubernetes to redeploy the previous
ReplicaSet's pod template — Kubernetes already kept the last 5 ReplicaSets around
(`revisionHistoryLimit: 5` from Part 3's `web.yaml`), so "undo" is instant, no rebuild needed.
