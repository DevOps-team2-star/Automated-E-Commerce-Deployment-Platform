#!/usr/bin/env bash
# Part 4: installs Prometheus + Alertmanager + Grafana (kube-prometheus-stack) and the shop's
# ServiceMonitors, alert rules and dashboards into the current kubectl context.
#   ./monitoring/install.sh                 -> then: ./monitoring/port-forward.sh
set -euo pipefail
cd "$(dirname "$0")"
NS=monitoring
CHART_VERSION=${CHART_VERSION:-}          # pin with CHART_VERSION=x.y.z if you need a fixed version

kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -

if ! kubectl -n $NS get secret grafana-admin >/dev/null 2>&1; then
  pw=$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 16)
  kubectl -n $NS create secret generic grafana-admin --from-literal=admin-user=admin --from-literal=admin-password="$pw"
fi

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update prometheus-community >/dev/null
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n $NS -f values.yaml ${CHART_VERSION:+--version "$CHART_VERSION"} --wait --timeout 10m

kubectl apply -k .

echo
echo "Grafana user: admin"
echo "Grafana password: $(kubectl -n $NS get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d)"
echo "Open with: ./monitoring/port-forward.sh  (Grafana http://localhost:3000, Prometheus http://localhost:9090)"
