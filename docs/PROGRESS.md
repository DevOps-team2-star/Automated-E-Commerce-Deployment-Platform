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
