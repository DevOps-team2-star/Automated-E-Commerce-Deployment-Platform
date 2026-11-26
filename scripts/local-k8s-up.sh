#!/usr/bin/env bash
# Part 3: create the local k3d cluster (if needed), build + import the images, deploy the shop.
#   ./scripts/local-k8s-up.sh            -> shop at http://localhost:${LB_PORT:-8888}
# LB_PORT defaults to 8888, not 8080, so this never collides with any other Jenkins/app you
# already have bound to 8080 on your machine (our own Jenkins in Part 5 uses 8090 anyway).
set -euo pipefail
cd "$(dirname "$0")/.."
CLUSTER=${CLUSTER:-shop}
LB_PORT=${LB_PORT:-8888}

REGISTRY_NAME=registry.localhost      # container k3d-registry.localhost, host port 5050
if ! k3d registry list -o json | jq -e '.[] | select(.name == "k3d-registry.localhost")' >/dev/null; then
  echo "==> Creating local image registry (push: localhost:5050, pull in cluster: k3d-registry.localhost:5050)"
  k3d registry create "$REGISTRY_NAME" --port 5050
fi

if ! k3d cluster list -o json | jq -e --arg c "$CLUSTER" '.[] | select(.name == $c)' >/dev/null; then
  echo "==> Creating k3d cluster '$CLUSTER' (1 server + 2 agents, Traefik off, host $LB_PORT -> LB :80)"
  k3d cluster create "$CLUSTER" --agents 2 \
    --registry-use "k3d-${REGISTRY_NAME}:5050" \
    -p "${LB_PORT}:80@loadbalancer" \
    --k3s-arg "--disable=traefik@server:0" \
    --k3s-arg "--tls-san=k3d-${CLUSTER}-serverlb@server:0" \
    --wait
fi
kubectl config use-context "k3d-$CLUSTER" >/dev/null

echo "==> Building images with docker compose (local/ecom-*:dev)"
[ -f docker/.env ] || cp docker/.env.example docker/.env
REGISTRY=local TAG=dev docker compose -f docker/docker-compose.yml --env-file docker/.env build db web search payment

echo "==> Importing images into the cluster (no registry needed locally)"
k3d image import -c "$CLUSTER" local/ecom-db:dev local/ecom-web:dev local/ecom-search:dev local/ecom-payment:dev

echo "==> Namespace + db-credentials secret (password from docker/.env)"
kubectl create namespace shop --dry-run=client -o yaml | kubectl apply -f -
pw=$(grep -E '^DB_PASSWORD=' docker/.env | cut -d= -f2-)
kubectl -n shop create secret generic db-credentials \
  --from-literal=password="$pw" \
  --from-literal=url="postgresql://postgres:${pw}@db:5432/shop" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Deploying"
kubectl apply -k k8s/overlays/local
kubectl -n shop rollout status statefulset/db --timeout=180s
for d in search payment web nginx; do kubectl -n shop rollout status deploy/$d --timeout=180s; done

kubectl -n shop get pods,svc,hpa
echo
echo "Shop:  http://localhost:${LB_PORT}"
echo "Check: curl -s http://localhost:${LB_PORT}/api/search/products | jq length"
