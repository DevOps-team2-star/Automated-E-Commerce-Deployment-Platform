#!/usr/bin/env bash
# Grafana on http://localhost:3000, Prometheus on http://localhost:9090, Alertmanager on http://localhost:9093
set -euo pipefail
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80 >/dev/null &
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 >/dev/null &
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-alertmanager 9093:9093 >/dev/null &
echo "Grafana http://localhost:3000 | Prometheus http://localhost:9090 | Alertmanager http://localhost:9093"
echo "Press Ctrl+C to stop"
wait
