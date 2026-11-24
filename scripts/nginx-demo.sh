#!/usr/bin/env bash
# Part 2 demo: shows path routing, load balancing over 3 search replicas and the payment rate limit.
# Needs the compose stack running (docker compose -f docker/docker-compose.yml up -d).
set -euo pipefail
cd "$(dirname "$0")/.."
C="docker compose -f docker/docker-compose.yml"
BASE=http://localhost:${NGINX_PORT:-80}

echo "== Routing"
for p in / /api/search/products /api/search/search?q=watch /api/payment/orders /healthz; do
  printf '  %-28s -> HTTP %s\n' "$p" "$(curl -s -o /dev/null -w '%{http_code}' "$BASE$p")"
done

echo "== Load balancing: scale search to 3 and restart nginx so it re-resolves the name"
$C up -d --scale search=3 --no-recreate search >/dev/null
$C restart nginx >/dev/null && sleep 3
for _ in $(seq 1 30); do curl -s -o /dev/null "$BASE/api/search/products"; done
echo "  requests per search container (from nginx access log 'upstream=' field):"
$C logs --since 1m nginx | grep -o 'upstream=[0-9.]*:8081' | sort | uniq -c | sed 's/^/   /'
$C up -d --scale search=1 search >/dev/null

echo "== Rate limit on /api/payment/ (10 r/s, burst 20): 60 fast requests"
codes=$(for _ in $(seq 1 60); do curl -s -o /dev/null -w '%{http_code}\n' "$BASE/api/payment/orders" & done; wait)
echo "$codes" | sort | uniq -c | sed 's/^/   HTTP /'
echo "  (429 = rejected by limit_req)"
