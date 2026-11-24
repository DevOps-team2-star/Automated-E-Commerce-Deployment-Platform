#!/usr/bin/env bash
# Automated rollback, layer 3: after a deploy, watch the 5xx ratio in Prometheus for a while.
# Fails (-> pipeline rollback) if it goes above the threshold. Prometheus is reached through the
# Kubernetes API server proxy, so no port-forward or extra network access is needed.
#   ./jenkins/scripts/metric-gate.sh [seconds=120] [threshold=0.05]
set -euo pipefail
WAIT=${1:-120}
MAX=${2:-0.05}
SVC=monitoring-kube-prometheus-prometheus
if ! kubectl -n monitoring get svc "$SVC" >/dev/null 2>&1; then
  echo "SKIP metric gate: Prometheus not installed in this cluster"; exit 0
fi
query='sum(rate(http_requests_total{namespace="shop",status=~"5.."}[1m])) / sum(rate(http_requests_total{namespace="shop"}[1m]))'
enc=$(jq -rn --arg q "$query" '$q|@uri')
end=$((SECONDS + WAIT))
while [ $SECONDS -lt $end ]; do
  ratio=$(kubectl get --raw "/api/v1/namespaces/monitoring/services/${SVC}:9090/proxy/api/v1/query?query=${enc}" \
          | jq -r '.data.result[0].value[1] // "0"')
  [ "$ratio" = "NaN" ] && ratio=0
  printf '%s  5xx ratio = %s (max %s)\n' "$(date +%T)" "$ratio" "$MAX"
  if awk -v r="$ratio" -v m="$MAX" 'BEGIN { exit !(r > m) }'; then
    echo "FAIL metric gate: 5xx ratio $ratio is above $MAX"; exit 1
  fi
  sleep 15
done
echo "PASS metric gate"
