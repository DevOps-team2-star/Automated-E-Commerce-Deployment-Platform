#!/usr/bin/env bash
# Part 4: makes payment return 5xx for 30% of requests, sends traffic, and shows ShopHighErrorRate
# going Pending -> Firing in Prometheus. Then restores payment.
#   ./monitoring/alert-demo.sh [shop-url]   default http://localhost:8080 (Prometheus via port-forward on 9090)
set -euo pipefail
URL=${1:-http://localhost:8080}
PROM=${PROM:-http://localhost:9090}
trap 'kubectl -n shop set env deploy/payment ERROR_RATE=0 >/dev/null; echo "payment restored (ERROR_RATE=0)"' EXIT
kubectl -n shop set env deploy/payment ERROR_RATE=0.3
kubectl -n shop rollout status deploy/payment --timeout=120s
echo "==> Sending payment traffic for 4 minutes and polling the alert state"
hey -z 240s -c 1 -q 2 -m POST -T application/json -d '{"product_id": 9, "quantity": 1}' "$URL/api/payment/pay" >/dev/null &
for _ in $(seq 1 24); do
  state=$(curl -s "$PROM/api/v1/alerts" | jq -r '[.data.alerts[] | select(.labels.alertname=="ShopHighErrorRate") | .state] | unique | join(",")')
  echo "$(date +%T)  ShopHighErrorRate: ${state:-inactive}"
  sleep 10
done
wait || true
