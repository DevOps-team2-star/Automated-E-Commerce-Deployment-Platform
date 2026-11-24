#!/usr/bin/env bash
# Part 6 demo without Jenkins: a bad web release (readiness always fails) is held back by the rolling
# update while traffic keeps flowing with no errors, then it is rolled back.
#   ./scripts/rollback-demo.sh [shop-url]    default http://localhost:8080
set -euo pipefail
URL=${1:-http://localhost:8080}
echo "==> Current web revision"; kubectl -n shop rollout history deploy/web | tail -n 3
echo "==> Background traffic for 150s"
hey -z 150s -c 10 "$URL/" > /tmp/hey-rollback.txt &
HEY=$!
sleep 5
echo "==> Bad release: FAIL_READY=true (new pods never become Ready)"
kubectl -n shop set env deploy/web FAIL_READY=true
if ! kubectl -n shop rollout status deploy/web --timeout=60s; then
  echo "==> Rollout stuck as expected; old pods still serve traffic:"
  kubectl -n shop get pods -l app=web
fi
echo "==> Automatic-style rollback: kubectl rollout undo"
kubectl -n shop rollout undo deploy/web
kubectl -n shop rollout status deploy/web --timeout=120s
wait $HEY || true
echo "==> Traffic during the whole bad release + rollback:"
grep -A10 "Status code distribution" /tmp/hey-rollback.txt
echo "(only [200] responses = zero downtime)"
