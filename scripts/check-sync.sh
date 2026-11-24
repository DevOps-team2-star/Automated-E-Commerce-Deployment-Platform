#!/usr/bin/env bash
# Kustomize can only read files inside its own folder, so k8s/base keeps copies of the Nginx
# config. This fails (Jenkins Lint stage) if a copy drifts from the original in nginx/.
set -euo pipefail
cd "$(dirname "$0")/.."
cmp nginx/default.conf k8s/base/nginx-default.conf
cmp nginx/50x.html     k8s/base/nginx-50x.html
echo "nginx config copies are in sync"
