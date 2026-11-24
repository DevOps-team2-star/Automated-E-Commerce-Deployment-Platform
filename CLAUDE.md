# CLAUDE.md — Automated E-Commerce Deployment Platform

## What this project is
A DevOps diploma project for Kareem (demo on 7 Dec 2026). The application code in `app/`
is provided and must NOT be rewritten; only fix it if a bug blocks a DevOps task, and say so.
All the work is DevOps: Docker, Nginx, Kubernetes + HPA, Prometheus/Grafana, Jenkins CI/CD,
automated rollback, Terraform (AWS EC2, RDS, S3, ALB), Ansible, Git.

The full plan, with phases, reference snippets and acceptance checks, is in `docs/PLAN.md`.
Follow it part by part. Where the plan's snippets are wrong or incomplete, fix them and note the
change in `docs/PROGRESS.md`.

## Fixed decisions (do not change without asking)
- Machine: Windows 11 + WSL2 Ubuntu, Docker Desktop with WSL integration. Work inside WSL paths.
- Local Kubernetes: k3d cluster named `shop` (Traefik disabled, port 8080 -> load balancer :80).
- AWS Kubernetes: k3s on EC2 (1 server t3.medium + `agent_count` agents t3.small), region eu-central-1.
- Edge proxy: Nginx everywhere. docker compose runs nginx/nginx.conf; Kubernetes runs the same config as
  an `nginx` Deployment + Service (LoadBalancer :80 locally via k3d, NodePort 30080 behind the ALB on AWS).
  The community ingress-nginx controller is NOT used: it was retired in March 2026 (no security fixes).
- Database: Postgres StatefulSet locally; RDS PostgreSQL 16 on AWS via a `db` ExternalName Service.
- Images: Docker Hub `docker.io/<DOCKERHUB_USER>/ecom-{web,search,payment}:<git-sha>`. Never `latest`.
- Config per environment: Kustomize `k8s/base` + `k8s/overlays/{local,aws}`.
- Monitoring: kube-prometheus-stack Helm chart, namespace `monitoring`; app namespace `shop`.
- CI/CD: Jenkins LTS in Docker on the laptop, jobs `shop-pipeline`, `shop-rollback`,
  `infra-apply`, `infra-destroy` (destroy also nightly 23:00 Africa/Cairo).
- Terraform: remote state in S3 with `use_lockfile = true`; modules network, compute, database,
  storage, loadbalancer; `terraform/bootstrap` creates the state bucket and is never destroyed.

## Safety rules
- NEVER run `terraform apply`, `terraform destroy`, or anything that creates or deletes AWS
  resources without asking Kareem first in that moment. `terraform plan` is fine.
- Never commit secrets: passwords, tokens, AWS keys, kubeconfigs, `.env`, `*.tfstate`, private keys.
  Use `.env` (git-ignored), Jenkins credentials, Kubernetes Secrets, Ansible Vault.
- Keep AWS cheap: no NAT gateway, no EKS, small instances, everything tagged
  `Project=ecommerce-devops`, `force_destroy`/`skip_final_snapshot` so destroy never blocks.
- Don't delete Docker volumes, the k3d cluster or Jenkins home without asking.

## How to work
- One part at a time, on a branch `feat/part-N-<name>`; commit in small steps with clear messages;
  merge to `main` when the part's "Done when" checks pass.
- After building, RUN the checks yourself (curl, kubectl, hey, promtool, terraform validate,
  ansible-playbook --syntax-check / --check) and show the evidence.
- At the end of each part, append to `docs/PROGRESS.md`: what was built, files, how to run it,
  how it was verified, deviations from the plan, and anything Kareem must do by hand.
- Also add a short `docs/explain/part-N.md`: plain-language explanation of every file created,
  the commands to demo it, and the 5 questions an instructor is most likely to ask, with answers.
- If a tool is missing in WSL, install it (apt, official install scripts) and record it in PROGRESS.md.
- When something needs Kareem (accounts, tokens, passwords, browser clicks), stop and list exactly
  what to do, then continue once he confirms.
