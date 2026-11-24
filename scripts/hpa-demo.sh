#!/usr/bin/env bash
# Part 3: load the search API for a few minutes and watch the HPA add pods, then remove them.
#   ./scripts/hpa-demo.sh [url] [seconds]   default http://localhost:8080  180
set -euo pipefail
URL=${1:-http://localhost:8080}
SECS=${2:-180}
echo "==> Before"; kubectl -n shop get hpa
echo "==> Load: hey -z ${SECS}s -c 60 $URL/api/search/search?q=a  (running in background)"
hey -z "${SECS}s" -c 60 "$URL/api/search/search?q=a" > /tmp/hey-hpa.txt &
HEY=$!
echo "==> Watching for ${SECS}s of load + 150s of cool-down"
end=$((SECONDS + SECS + 150))
while [ $SECONDS -lt $end ]; do
  printf '%s  ' "$(date +%T)"; kubectl -n shop get hpa search -o jsonpath='search cpu={.status.currentMetrics[0].resource.current.averageUtilization}% (target 60%) replicas={.status.currentReplicas}{"\n"}'
  sleep 10
done
wait $HEY || true
echo "==> Load test summary"; grep -E "Requests/sec|Status code|\[" /tmp/hey-hpa.txt | head -n 12
