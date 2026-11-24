#!/usr/bin/env bash
# Smoke test of a deployed shop (local k3d or AWS) through its Nginx entry point.
#   ./jenkins/scripts/smoke-test.sh http://k3d-shop-serverlb      (from Jenkins, local cluster)
#   ./jenkins/scripts/smoke-test.sh http://localhost:8080          (from your shell, local cluster)
#   ./jenkins/scripts/smoke-test.sh http://<alb-dns-name>          (AWS)
set -euo pipefail
BASE=${1:?usage: smoke-test.sh <base-url>}
BASE=${BASE%/}

retry() { for _ in $(seq 1 20); do if "$@"; then return 0; fi; sleep 3; done; return 1; }
check() {
  local name=$1 path=$2
  if retry curl -fsS -m 10 -o /dev/null "$BASE$path"; then echo "PASS $name"; else echo "FAIL $name ($BASE$path)"; exit 1; fi
}

check "nginx health"  /healthz
check "storefront"    /
check "product list"  /api/search/products
check "search query"  "/api/search/search?q=watch"
check "payment ready" /api/payment/ready

order=$(curl -fsS -m 10 -X POST -H 'Content-Type: application/json' \
  -d '{"product_id": 3, "quantity": 1, "card": "4242424242424242"}' "$BASE/api/payment/pay")
if echo "$order" | grep -q '"status": *"paid"'; then echo "PASS purchase -> $order"; else echo "FAIL purchase: $order"; exit 1; fi

version=$(curl -fsS -m 10 "$BASE/" | grep -o 'version [^<]*' | head -n 1 || true)
echo "Storefront reports: ${version:-unknown version}"
echo "Smoke test passed for $BASE"
