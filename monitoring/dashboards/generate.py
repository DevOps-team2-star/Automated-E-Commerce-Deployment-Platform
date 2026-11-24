"""Generates the two Grafana dashboards as JSON (dashboards as code).

Run: python3 monitoring/dashboards/generate.py   -> writes shop-golden-signals.json, shop-scaling.json
The JSON files are committed and loaded into Grafana by a ConfigMap (monitoring/kustomization.yaml).
"""
import json
import pathlib

DS = {"type": "prometheus", "uid": "prometheus"}  # default datasource uid in kube-prometheus-stack
HERE = pathlib.Path(__file__).parent


def panel(pid, title, exprs, x, y, w=12, h=8, unit="short", kind="timeseries", legend="{{service}}"):
    targets = [{"datasource": DS, "expr": e, "legendFormat": legend, "refId": chr(65 + i)} for i, e in enumerate(exprs)]
    p = {
        "id": pid, "type": kind, "title": title, "datasource": DS, "targets": targets,
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "fieldConfig": {"defaults": {"unit": unit}, "overrides": []},
        "options": {},
    }
    if kind == "timeseries":
        p["fieldConfig"]["defaults"]["custom"] = {"lineWidth": 2, "fillOpacity": 10}
        p["options"] = {"legend": {"displayMode": "list", "placement": "bottom"}, "tooltip": {"mode": "multi"}}
    if kind == "stat":
        p["options"] = {"reduceOptions": {"calcs": ["lastNotNull"]}, "colorMode": "value", "graphMode": "area"}
    return p


def dashboard(uid, title, panels):
    return {
        "uid": uid, "title": title, "tags": ["shop"], "timezone": "browser", "schemaVersion": 39,
        "refresh": "10s", "time": {"from": "now-30m", "to": "now"}, "editable": True, "panels": panels,
    }


golden = dashboard("shop-golden", "Shop - Golden Signals", [
    panel(1, "Orders per minute", ['sum(rate(shop_orders_total[5m])) * 60'], 0, 0, 6, 5, kind="stat", legend="orders/min"),
    panel(2, "Requests per second (all)", ['sum(rate(http_requests_total[1m]))'], 6, 0, 6, 5, unit="reqps", kind="stat", legend="req/s"),
    panel(3, "5xx ratio (all)", ['sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))'],
          12, 0, 6, 5, unit="percentunit", kind="stat", legend="5xx"),
    panel(4, "Payment failures per minute", ['sum by (reason) (rate(shop_payment_failures_total[5m])) * 60'], 18, 0, 6, 5,
          kind="stat", legend="{{reason}}"),
    panel(5, "Traffic: requests/s by service", ['sum by (service) (rate(http_requests_total[1m]))'], 0, 5, unit="reqps"),
    panel(6, "Errors: 5xx ratio by service",
          ['sum by (service) (rate(http_requests_total{status=~"5.."}[5m])) / sum by (service) (rate(http_requests_total[5m]))'],
          12, 5, unit="percentunit"),
    panel(7, "Latency: p95 by service",
          ['histogram_quantile(0.95, sum by (le, service) (rate(http_request_duration_seconds_bucket[5m])))'], 0, 13, unit="s"),
    panel(8, "Saturation: CPU vs request by pod",
          ['sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="shop", container!="", container!="POD"}[2m]))'
           ' / sum by (pod) (kube_pod_container_resource_requests{namespace="shop", resource="cpu"})'],
          12, 13, unit="percentunit", legend="{{pod}}"),
    panel(9, "Nginx: active connections and requests/s",
          ['sum(nginx_connections_active)', 'sum(rate(nginx_http_requests_total[1m]))'], 0, 21, 24, 7, legend="nginx"),
])

scaling = dashboard("shop-scaling", "Shop - Scaling", [
    panel(1, "HPA replicas (current vs max)",
          ['kube_horizontalpodautoscaler_status_current_replicas{namespace="shop"}',
           'kube_horizontalpodautoscaler_spec_max_replicas{namespace="shop"}'],
          0, 0, 24, 8, legend="{{horizontalpodautoscaler}}"),
    panel(2, "CPU used by search and web pods (cores)",
          ['sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="shop", pod=~"(search|web)-.*", container!="", container!="POD"}[1m]))'],
          0, 8, legend="{{pod}}"),
    panel(3, "Requests/s by service", ['sum by (service) (rate(http_requests_total[1m]))'], 12, 8, unit="reqps"),
    panel(4, "Ready pods by deployment",
          ['kube_deployment_status_replicas_available{namespace="shop"}'], 0, 16, legend="{{deployment}}"),
    panel(5, "Node CPU utilisation",
          ['1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[2m]))'], 12, 16, unit="percentunit", legend="{{instance}}"),
])

for name, d in (("shop-golden-signals.json", golden), ("shop-scaling.json", scaling)):
    (HERE / name).write_text(json.dumps(d, indent=2) + "\n")
    print("wrote", name)
