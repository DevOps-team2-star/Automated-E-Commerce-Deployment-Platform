#!/usr/bin/env bash
# Builds and (re)starts the Jenkins controller in Docker on the k3d network.
#   cp jenkins/.env.example jenkins/.env   # fill it in
#   ./jenkins/run-jenkins.sh               -> http://localhost:8090 (user admin)
#
# - The host Docker socket is mounted so pipelines can build and run containers.
# - Jenkins joins the `k3d-<cluster>` network so it reaches the local cluster at k3d-<cluster>-serverlb.
# - Kubeconfigs live in the jenkins_home volume under kube/<env>.yaml (local written here, aws by Ansible).
set -euo pipefail
cd "$(dirname "$0")"
CLUSTER=${CLUSTER:-shop}
NAME=jenkins

[ -f .env ] || { echo "Create jenkins/.env from jenkins/.env.example first"; exit 1; }

echo "==> Building image my-jenkins"
docker build -t my-jenkins .

docker volume create jenkins_home >/dev/null
SOCK_GID=$(stat -c %g /var/run/docker.sock)

if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "==> Replacing existing container"
  docker rm -f "$NAME" >/dev/null
fi

NET_ARGS=()
if docker network inspect "k3d-$CLUSTER" >/dev/null 2>&1; then NET_ARGS=(--network "k3d-$CLUSTER"); fi

docker run -d --name "$NAME" --restart unless-stopped \
  -p 8090:8080 \
  "${NET_ARGS[@]}" \
  --group-add "$SOCK_GID" \
  --env-file .env \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  my-jenkins

echo "==> Writing kubeconfig for the local cluster into jenkins_home/kube/local.yaml"
if command -v k3d >/dev/null && k3d cluster list "$CLUSTER" >/dev/null 2>&1; then
  k3d kubeconfig get "$CLUSTER" \
    | sed -E "s#https://(0\.0\.0\.0|127\.0\.0\.1|localhost):[0-9]+#https://k3d-${CLUSTER}-serverlb:6443#" \
    > /tmp/kubeconfig-local.yaml
  docker exec "$NAME" mkdir -p /var/jenkins_home/kube
  docker cp /tmp/kubeconfig-local.yaml "$NAME":/var/jenkins_home/kube/local.yaml
  docker exec -u root "$NAME" chown -R jenkins:jenkins /var/jenkins_home/kube
  rm -f /tmp/kubeconfig-local.yaml
else
  echo "   (k3d cluster '$CLUSTER' not found - run scripts/local-k8s-up.sh, then re-run this script)"
fi

echo "==> Waiting for Jenkins to start"
for _ in $(seq 1 60); do
  if curl -s -o /dev/null -w '%{http_code}' http://localhost:8090/login | grep -q 200; then break; fi
  sleep 5
done
echo "Jenkins: http://localhost:8090  (user: admin, password: JENKINS_ADMIN_PASSWORD from jenkins/.env)"
echo "Jobs: shop-pipeline, shop-rollback, infra-apply, infra-destroy"
