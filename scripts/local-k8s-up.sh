#!/usr/bin/env bash
# Part 3: create the local k3d cluster (if needed), build + import the images, deploy the shop.
#   ./scripts/local-k8s-up.sh            -> shop at http://localhost:8080
set -euo pipefail
cd "$(dirname "$0")/.."
CLUSTER=${CLUSTER:-shop}

if ! k3d cluster list -o json | jq -e --arg c "$CLUSTER" '.[] | select(.name == $c)' >/dev/null; then
  echo "==> Creating k3d cluster '$CLUSTER' (1 server + 2 agents, Traefik off, host 8080 -> LB :80)"
  k3d cluster create "$CLUSTER" --agents 2 \
    -p "8080:80@loadbalancer" \
    --k3s-arg "--disable=traefik@server:0" \
    --wait
fi
kubectl config use-context "k3d-$CLUSTER" >/dev/null

echo "==> Building images with docker compose (local/ecom-*:dev)"
[ -f docker/.env ] || cp docker/.env.example docker/.env
REGISTRY=local TAG=dev docker compose -f docker/docker-compose.yml --env-file docker/.env build db web search payment

echo "==> Importing images into the cluster (no registry needed locally)"
k3d image import -c "$CLUSTER" local/ecom-db:dev local/ecom-web:dev local/ecom-search:dev local/ecom-payment:dev

echo "==> DB credentials secret source (k8s/overlays/local/db.env, git-ignored)"
if [ ! -f k8s/overlays/local/db.env ]; then
  pw=$(grep -E '^DB_PASSWORD=' docker/.env | cut -d= -f2-)
  printf 'password=%s\nurl=postgresql://postgres:%s@db:5432/shop\n' "$pw" "$pw" > k8s/overlays/local/db.env
fi

echo "==> Deploying"
kubectl apply -k k8s/overlays/local
kubectl -n shop rollout status statefulset/db --timeout=180s
for d in search payment web nginx; do kubectl -n shop rollout status deploy/$d --timeout=180s; done

kubectl -n shop get pods,svc,hpa
echo
echo "Shop:  http://localhost:8080"
echo "Check: curl -s http://localhost:8080/api/search/products | jq length"
