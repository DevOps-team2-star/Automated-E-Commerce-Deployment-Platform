# Part 0 explained — Machine setup (WSL2, Docker, CLI tools, Git repo)

Plain-language walkthrough of every file in this part, so you can explain it to the instructor
without re-reading the code live. Pair this with `docs/HANDS-ON-GUIDE.md` for the test steps.

## Why this part exists
Everything else in the project (Docker, Kubernetes, Terraform, Ansible, Jenkins) is a command-line
tool. Before any of that can run, your laptop needs: (1) a Linux environment (WSL2 Ubuntu, since
these tools are built for Linux, not native Windows), (2) Docker itself, and (3) every CLI those
later parts call. Part 0 is "get the toolbox on the workbench" — nothing about the shop app yet.

## File-by-file

### `scripts/install-tools.sh`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/scripts/install-tools.sh)

A bash script you run once (and safely re-run any time). Structure, top to bottom:

- `set -euo pipefail` — stop immediately on any error, undefined variable, or failed step in a
  pipe. Standard "fail loudly, don't limp along" setting for install scripts.
- `need() { ! command -v "$1" >/dev/null 2>&1; }` — a tiny helper function: `need kubectl` returns
  true only if `kubectl` is **not** already on the PATH. This is what makes the whole script
  idempotent (safe to run twice) — every tool is wrapped in `if need <tool>; then ... fi`, so an
  already-installed tool is skipped.
- `warn() { echo "WARNING: $*" >&2; }` — prints a warning to stderr instead of crashing the whole
  script. Used only for the two "nice to have, not critical" tools (`hey`, `hadolint`) — this is
  the fix from PR #12, after the original script died on a broken `hey` download before it ever
  got to install the tools that actually matter.
- `apt-get install ...` block — base packages every later step needs (`curl`, `unzip`, `jq` for
  parsing JSON, `git`, `gnupg`/`ca-certificates` for verifying downloaded packages, `pipx` for
  installing Python CLI tools in isolated environments).
- One `if need X; then ... fi` block per tool: `kubectl` (downloaded straight from the official
  Kubernetes release URL), `k3d` (official install script, piped into bash), `helm`, `kustomize`,
  `terraform` (added as a proper apt repo from HashiCorp, so it stays updatable via `apt upgrade`),
  `ansible` (installed with `pipx`, which keeps it in its own isolated Python environment so it
  can't conflict with your system Python), `aws` CLI v2 (downloaded as a zip, unpacked, installed).
- `hey` (an HTTP load-testing tool used later for the Kubernetes HPA demo) and `hadolint` (a
  Dockerfile linter) are last, and wrapped with `warn` instead of being allowed to kill the script.

**Why install each tool this way instead of one single command?** Every tool here has an official,
first-party install method (its own apt repo, or its own install script, or its own GitHub
release) — using the official method means you get the real checksum/signing behavior that
project maintains, not a possibly-outdated distro package.

### `scripts/check-tools.sh`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/scripts/check-tools.sh)

Much simpler: a `check()` helper that runs `<tool> --version` (or equivalent), prints "OK" plus
the version line, or "MISSING" if the command fails — and sets `fail=1` so the script's exit code
is non-zero if anything is missing (useful later inside Jenkins, where a non-zero exit fails the
build). This script changes nothing on your machine — it's pure read-only verification.

### `CLAUDE.md`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/CLAUDE.md)

Not code — this is the project's own "constitution": fixed decisions (machine spec, cluster name
`shop`, image naming, why we don't use the retired `ingress-nginx`), safety rules (never run real
`terraform apply`/`destroy` without asking first, never commit secrets), and the required workflow
(one branch per part, run checks yourself, update `docs/PROGRESS.md`). Worth reading once end to
end — it explains *why* later parts are built the way they are.

### The Git repo itself
Branches exist per part (`feat/part-0-setup`, `feat/part-1-docker`, …) and get merged into `main`
once each part is confirmed. `main` is always the "currently true" state of the project.

## How to demo this part
```bash
cd ~/automated-e-commerce-deployment-platform
git checkout main && git pull
bash scripts/check-tools.sh
```
Expected: every line says `OK` with a version number. If anything says `MISSING`, run
`bash scripts/install-tools.sh`, then re-run `check-tools.sh`.

## 5 questions an instructor might ask

**1. Why WSL2 instead of native Windows or a full Linux VM?**
WSL2 runs a real Linux kernel (lighter than a traditional VM) while still integrating with Docker
Desktop and the Windows filesystem — it's the standard way to do Linux-based DevOps work on a
Windows laptop without dual-booting.

**2. Why is `install-tools.sh` idempotent instead of just reinstalling everything each time?**
So it's safe to re-run after a tool update or a new team member's laptop, without reinstalling
things that already work, and without risk of a partial, order-dependent failure wiping out a
previously-fine install.

**3. Why pin terraform to HashiCorp's own apt repo instead of `apt install terraform` from Ubuntu's
default repos?**
Ubuntu's default repos either don't carry Terraform at all or carry a stale version; the vendor's
own repo gives the current release and lets `apt upgrade` keep it current going forward.

**4. What happens if `hey` or `hadolint` fail to install?**
Nothing fatal — the script prints a `WARNING` and moves on, because those two are only used for
optional load-testing (`hpa-demo.sh`, `rollback-demo.sh`) and an optional Dockerfile lint step
that Jenkins also performs its own way. All the project-critical tools (`docker`, `kubectl`, `k3d`,
`terraform`, `ansible`) still have to succeed or the script stops.

**5. How do you know this script actually ran correctly, beyond "it didn't crash"?**
`check-tools.sh` is the real verification — it independently calls each tool's own version command
and reports pass/fail per tool, so "the install script finished" and "the tools actually work" are
checked separately.
