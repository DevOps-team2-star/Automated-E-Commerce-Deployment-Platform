# Prompts for Claude Code (copy one at a time)

Use a **WSL** session on the `ecommerce-devops` folder. Start each part in **Plan** mode,
read the plan, then switch to **Accept edits** to build it. For Parts 7 to 9 (AWS) use **Manual**
so every command that touches AWS needs your click.

Start a **new session for each part**. CLAUDE.md, docs/PLAN.md and docs/PROGRESS.md carry the context.

---

## 0. Kick-off (once)
```
Read CLAUDE.md, docs/PLAN.md and README.md. Then:
1. Check which tools from Part 0 are installed in this WSL distro (docker, git, kubectl, k3d,
   helm, terraform, ansible, aws, jq, hey, hadolint) and install the missing ones.
2. Verify Docker Desktop integration with `docker run hello-world`.
3. Initialise git if needed, make the first commit, and create docs/PROGRESS.md.
4. Tell me exactly what I must do by hand (GitHub repo, Docker Hub token, AWS IAM user,
   Budget alert) and wait for me.
```

## 1. Docker (Part 1)
```
Build Part 1 from docs/PLAN.md: Dockerfiles for web, search, payment (multi-stage, non-root,
HEALTHCHECK, .dockerignore), docker/docker-compose.yml with db + the 3 services, .env.example.
Bring the stack up, prove /health, /ready, a search query and a purchase that writes to the
orders table. Show image sizes and that containers run as non-root. Then follow the
"How to work" section of CLAUDE.md.
```

## 2. Nginx (Part 2)
```
Build Part 2: nginx/nginx.conf and an nginx service in compose as the only published port.
Route /, /api/search/, /api/payment/ (rate limited), /nginx_status. Prove each route with curl,
prove load spreading with search scaled to 3, prove the rate limit with hey. Also write
k8s/base/ingress.yaml with the same paths. Then follow CLAUDE.md "How to work".
```

## 3. Kubernetes + HPA (Part 3)
```
Build Part 3: k3d cluster `shop`, ingress-nginx via Helm, k8s/base (Deployments with probes,
resources, revisionHistoryLimit, rolling update maxUnavailable 0; Services; Ingress; HPAs for
web and search) and k8s/overlays/local (Postgres StatefulSet + PVC + init SQL ConfigMap,
db-credentials Secret generated from .env, image tags). Import or push images so the cluster can
pull them. Deploy with kubectl apply -k, open http://shop.localhost:8080, then run a hey load test
and show the HPA scaling out and back in. Also prepare k8s/overlays/aws (ExternalName db, replica
counts) without deploying it. Then follow CLAUDE.md "How to work".
```

## 4. Monitoring (Part 4)
```
Build Part 4: kube-prometheus-stack with monitoring/values.yaml, a ServiceMonitor for the shop,
PrometheusRules ShopHighErrorRate and ShopPodCrashLooping, and two Grafana dashboards stored as
JSON in monitoring/dashboards and loaded by a ConfigMap (Golden Signals, Scaling). Prove targets
are UP, run the PromQL queries from the plan, and trigger + resolve both alerts. Add a script
monitoring/install.sh that installs everything. Then follow CLAUDE.md "How to work".
```

## 5. Jenkins CI/CD (Part 5)
```
Build Part 5: jenkins/Dockerfile (Jenkins LTS + docker CLI, kubectl, kustomize, helm, terraform,
ansible, aws cli, plugins via plugins.txt), a script that runs it on the k3d-shop network with the
Docker socket, Configuration-as-Code (JCasC) for the jobs and credential placeholders if possible,
jenkins/Jenkinsfile with the stages in the plan, jenkins/scripts/compose-smoke-test.sh and
smoke-test.sh. Run the pipeline against TARGET_ENV=local and prove a code change (STORE_TITLE in
app/web/app.py) reaches the cluster with zero failed requests while hey runs. List the
credentials I must enter in the Jenkins UI. Then follow CLAUDE.md "How to work".
```

## 6. Rollback (Part 6)
```
Build Part 6: jenkins/scripts/rollback.sh wired into post { failure }, the Prometheus 5xx
metric gate in Verify, and jenkins/Jenkinsfile.rollback (SERVICE, REVISION). Demonstrate:
(a) FAIL_READY=true release is stopped by readiness and rolled back automatically by Jenkins,
(b) ERROR_RATE=0.3 on payment trips the metric gate and rolls back, (c) the manual job restores a
chosen revision. Keep hey running and show the site never went down. Then follow CLAUDE.md
"How to work".
```

## 7. Terraform (Part 7) — Manual mode
```
Build Part 7 from the plan: terraform/bootstrap (state bucket, versioning, encryption, public
access block), terraform/modules/{network,compute,database,storage,loadbalancer},
terraform/envs/demo with backend, variables (with validation), demo.tfvars, outputs, and the
templatefile that writes ansible/inventory/aws.ini and ansible/group_vars/all/tf.yml. Also
jenkins/Jenkinsfile.infra (apply/destroy, nightly destroy). Run fmt, validate and plan only.
Show me the plan summary and estimated hourly cost, then STOP and ask before any apply.
```
After you approve: `Apply the bootstrap, then apply envs/demo. Show outputs. Then destroy envs/demo and confirm the console is empty.`

## 8. Ansible (Part 8) — Manual mode
```
Build Part 8: ansible.cfg, site.yml, roles common, k3s_server, k3s_agent, platform (ingress-nginx
NodePort 30080 + kube-prometheus-stack via kubernetes.core.helm), app_config (namespace, db
Secret, ExternalName with the RDS endpoint, run init.sql against RDS once), vault example.
Syntax-check and lint everything locally. Then ask me before applying Terraform; after I approve,
run site.yml, show kubectl get nodes, run it again to prove changed=0, and ask before destroying.
```

## 9. Full AWS run + demo prep (Part 9) — Manual mode
```
Wire infra-apply end to end (Terraform -> Ansible -> shop-pipeline TARGET_ENV=aws) and run it
after asking me. Walk through the demo script in docs/PLAN.md Part 9 step by step and check every
step works on AWS, including HPA, rollback and alerts. Write docs/DEMO.md (exact commands and
URLs) and update README.md. Capture the screenshots list. Then ask me and run infra-destroy, and
verify no EC2, RDS, ALB or Elastic IP remains.
```

---

## Study prompts (after it works)
- `Explain Part 3 file by file as if I am a beginner. Then quiz me with 5 questions, one at a time, and correct my answers.`
- `Break the rollback on purpose and let me find the cause myself. Give hints only when I ask.`
- `Act as my instructor. Ask me 10 mixed questions from docs/PLAN.md "Questions bank" and grade me.`
- `Show me how a request travels from the ALB to a payment pod, with the commands to see each hop.`
