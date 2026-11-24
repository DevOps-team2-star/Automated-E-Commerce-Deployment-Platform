#!/usr/bin/env bash
# Automated rollback (deliverable 8, layer 2): undo the last rollout of every shop service.
# Called by the pipeline's post { failure } block when a deploy was attempted and failed.
# A service that has no previous revision (very first deploy) is skipped.
set -uo pipefail
SERVICES=${SERVICES:-web search payment}
rc=0
for s in $SERVICES; do
  revs=$(kubectl -n shop rollout history "deploy/$s" 2>/dev/null | awk 'NR>2 && $1 ~ /^[0-9]+$/ {print $1}' | wc -l)
  if [ "$revs" -lt 2 ]; then
    echo "SKIP $s: no previous revision to return to"
    continue
  fi
  echo "ROLLBACK $s"
  kubectl -n shop rollout undo "deploy/$s"
  if kubectl -n shop rollout status "deploy/$s" --timeout=150s; then
    echo "OK $s is back on its previous revision"
  else
    echo "ERROR $s did not become ready after rollback"; rc=1
  fi
done
kubectl -n shop get deploy -o wide
exit $rc
