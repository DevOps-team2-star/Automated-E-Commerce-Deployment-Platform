#!/usr/bin/env bash
# Brings the compose stack up, checks every service and one purchase through Nginx, then
# tears it down. Used by `make compose-test` and by the Jenkins "Test" stage.
#   KEEP=1 ./scripts/compose-smoke-test.sh   -> leave the stack running afterwards
set -euo pipefail
cd "$(dirname "$0")/.."
COMPOSE="docker compose -f docker/docker-compose.yml -p shop-test"
BASE=${BASE:-http://localhost:${NGINX_PORT:-80}}

[ -f docker/.env ] || cp docker/.env.example docker/.env

cleanup() { [ "${KEEP:-0}" = "1" ] || $COMPOSE down -v --remove-orphans >/dev/null 2>&1 || true; }
trap cleanup EXIT

$COMPOSE --env-file docker/.env up -d --build --wait --wait-timeout 180

retry() { for _ in $(seq 1 30); do if "$@"; then return 0; fi; sleep 2; done; return 1; }
check() { local name=$1 url=$2; if retry curl -fsS -o /dev/null "$url"; then echo "PASS $name"; else echo "FAIL $name ($url)"; exit 1; fi; }

check "storefront"         "$BASE/"
check "search api"         "$BASE/api/search/products"
check "search query"       "$BASE/api/search/search?q=shoe"
check "payment ready"      "$BASE/api/payment/ready"

order=$(curl -fsS -X POST -H 'Content-Type: application/json' \
  -d '{"product_id": 1, "quantity": 1, "card": "4242424242424242"}' "$BASE/api/payment/pay")
echo "$order" | grep -q '"status":"paid"' && echo "PASS purchase -> $order" || { echo "FAIL purchase: $order"; exit 1; }

declined=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
  -d '{"product_id": 1, "card": "4000000000000000"}' "$BASE/api/payment/pay")
[ "$declined" = "402" ] && echo "PASS declined card -> 402" || { echo "FAIL declined card -> $declined"; exit 1; }

echo "All compose smoke tests passed"
