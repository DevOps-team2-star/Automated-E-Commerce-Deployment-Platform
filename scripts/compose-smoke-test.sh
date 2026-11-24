#!/usr/bin/env bash
# Builds and starts the compose stack under a separate project name, checks every route and a
# purchase THROUGH NGINX, then tears everything down. Used locally and by the Jenkins "Test" stage.
#
# Requests are sent from a curl container attached to the stack's network, so the script works the
# same from a normal shell and from inside the Jenkins container (which talks to the host Docker
# through the socket and cannot reach the host's localhost).
#
#   KEEP=1 ./scripts/compose-smoke-test.sh   -> leave the test stack running afterwards
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT=${PROJECT:-shop-test}
export NGINX_PORT=${NGINX_PORT:-18080}      # avoid clashing with a dev stack on port 80
COMPOSE="docker compose -f docker/docker-compose.yml -p $PROJECT"
CURL_C="${PROJECT}-curl"
BASE=http://nginx:8080

[ -f docker/.env ] || cp docker/.env.example docker/.env

cleanup() {
  docker rm -f "$CURL_C" >/dev/null 2>&1 || true
  if [ "${KEEP:-0}" != "1" ]; then $COMPOSE down -v --remove-orphans >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

echo "== Build and start ($PROJECT)"
$COMPOSE --env-file docker/.env up -d --build --wait --wait-timeout 240

docker run -d --rm --name "$CURL_C" --network "${PROJECT}_default" --entrypoint sleep \
  curlimages/curl:latest 600 >/dev/null
c() { docker exec "$CURL_C" curl "$@"; }

retry() { for _ in $(seq 1 30); do if "$@"; then return 0; fi; sleep 2; done; return 1; }
check() {
  local name=$1 path=$2
  if retry c -fsS -o /dev/null "$BASE$path"; then echo "PASS $name ($path)"; else echo "FAIL $name ($path)"; exit 1; fi
}

echo "== Checks through nginx"
check "nginx health"   /healthz
check "storefront"     /
check "product list"   /api/search/products
check "search query"   "/api/search/search?q=shoe"
check "payment ready"  /api/payment/ready

order=$(c -fsS -X POST -H 'Content-Type: application/json' \
  -d '{"product_id": 1, "quantity": 1, "card": "4242424242424242"}' "$BASE/api/payment/pay")
if echo "$order" | grep -q '"status": *"paid"'; then echo "PASS purchase -> $order"; else echo "FAIL purchase: $order"; exit 1; fi

code=$(c -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
  -d '{"product_id": 1, "card": "4000000000000000"}' "$BASE/api/payment/pay")
if [ "$code" = "402" ]; then echo "PASS declined card -> 402"; else echo "FAIL declined card -> $code"; exit 1; fi

echo "All compose smoke tests passed"
