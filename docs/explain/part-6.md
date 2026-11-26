# Part 6 explained — Automated rollback

## Why this part exists
Deployments fail. The question isn't whether a bad release ever ships, it's how fast and how
automatically the system recovers — ideally with zero downtime and no human paged at 3am. `CLAUDE.md`
describes this as 5 layers, each catching what the one before it might miss:

1. Kubernetes rolling update (`maxUnavailable: 0`) + readiness probes — Part 3
2. Jenkins `post { failure }` running `kubectl rollout undo` — Part 5
3. Prometheus 5xx-ratio metric gate during the pipeline's Verify stage — Part 5
4. A manual one-click Jenkins rollback job — this part
5. Terraform/S3 state versioning for infra rollback — Part 7

This part demonstrates layers 1 and 2 concretely (without needing Jenkins), and ships layer 4 as
its own Jenkins job.

## File-by-file

### `scripts/rollback-demo.sh`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/scripts/rollback-demo.sh)

Proves layer 1+2 with real traffic, not just reading the YAML:
1. Starts `hey` (the load generator from Part 0) sending continuous traffic to the storefront in
   the background for 150 seconds.
2. While traffic is flowing, deliberately ships a broken release: `kubectl set env deploy/web
   FAIL_READY=true` — flips an environment variable the app code (Part 1) checks to make `/ready`
   always fail.
3. Because of `maxUnavailable: 0` (Part 3's `web.yaml`), Kubernetes refuses to take any old, working
   pod down until a new one passes its readiness probe — since the new ones never will, the
   rollout just sits there, **old pods keep serving every request**.
4. `kubectl rollout undo` reverts to the last working revision (this is the exact command
   `jenkins/scripts/rollback.sh` runs automatically in Part 5).
5. Checks the captured `hey` output for the HTTP status code distribution — if the whole exercise
   only shows `[200]` responses, that's proof of **zero downtime**: real traffic never saw a single
   error despite a broken deploy happening live.

### `jenkins/Jenkinsfile.rollback` (the `shop-rollback` job)
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/jenkins/Jenkinsfile.rollback)

Rollback layer 4 — a deliberate, human-triggered escape hatch, separate from the automatic one in
the main pipeline. Three stages: **History** (shows `kubectl rollout history` so a human can pick a
specific revision, not just "the previous one"), **Roll back** (`rollout undo`, optionally to a
specific `--to-revision`), **Result** (prints the final image tag running, so the person who
triggered it can confirm exactly what's live now). This exists for the case automatic rollback
doesn't cover: a release that *looks* healthy (passes readiness, doesn't trip the metric gate) but
is wrong in some way a human noticed afterward — a bad product price, a UI bug, etc.

### `jenkins/scripts/rollback.sh` (layer 2, used by the main pipeline)
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/jenkins/scripts/rollback.sh)

Called automatically from `jenkins/Jenkinsfile`'s `post { failure }` block (Part 5) — loops over
`web`, `search`, `payment`, checks each has a previous revision to go back to (skips if not — e.g.
the very first deploy ever), and runs `rollout undo` + waits for it to actually become ready, not
just that the command was accepted.

### `jenkins/scripts/metric-gate.sh` (layer 3, used by the main pipeline's Verify stage)
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/jenkins/scripts/metric-gate.sh)

Queries Prometheus (through the Kubernetes API server's own proxy — no extra network path needed)
for the ratio of 5xx responses to total requests over a rolling window, polling every 15 seconds for
up to 2 minutes. If the ratio ever exceeds the threshold (default 5%), it exits non-zero — which is
exactly what makes the pipeline's Verify stage fail and trigger layer 2's automatic rollback. This
is the layer that catches a release that passes health checks but is quietly broken for real users.

## How to demo this part
```bash
cd ~/automated-e-commerce-deployment-platform
bash scripts/rollback-demo.sh http://localhost:8888
```
Watch the output: a stuck rollout, then an automatic-style rollback, then a status code breakdown
that should show only `[200]`.

## 5 questions an instructor might ask

**1. Why does `maxUnavailable: 0` matter for zero-downtime rollback?**
It tells Kubernetes never to remove a working pod until its replacement is proven ready — so a
broken release simply fails to roll out instead of taking capacity offline, and old pods keep
serving the entire time.

**2. What's the difference between layer 2 (pipeline auto-rollback) and layer 4 (manual
`shop-rollback` job)?**
Layer 2 fires automatically when the pipeline itself detects a failure (readiness never passes, or
the metric gate trips) — no human involved. Layer 4 is for a human who noticed a problem the
automated checks didn't catch, and wants to pick exactly which revision to return to.

**3. Why poll Prometheus for 2 minutes instead of just checking once right after deploy?**
A single bad request right at deploy time could be noise; sustained elevated error rate over a
real window is a much stronger signal that something is actually wrong, while still being short
enough not to leave a broken release live for long.

**4. How does `kubectl rollout undo` know what the "previous" version was?**
Kubernetes keeps old ReplicaSets around after a Deployment update, up to
`revisionHistoryLimit` (set to 5 in Part 3's manifests) — `rollout undo` just scales the most recent
old ReplicaSet back up and the current one down; no rebuild or image pull from scratch needed.

**5. Is this rollback fully automatic, or does it need a human every time?**
Layers 1-3 require zero human involvement — the pipeline detects and reverts failures on its own.
Layer 4 exists specifically for cases those three can't catch (a logically-wrong but technically
healthy release), and is the one layer that's manual by design.
