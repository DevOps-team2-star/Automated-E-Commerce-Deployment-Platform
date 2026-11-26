# Part 4 explained — Monitoring (Prometheus + Grafana)

## Why this part exists
Kubernetes (Part 3) keeps the app running, but gives no visibility into *how well*. Is CPU usage
climbing? Are requests failing? Is the HPA stuck maxed-out? Monitoring answers "is it actually
healthy right now" without SSH-ing into anything — the same question an instructor will ask live.

## File-by-file

### `monitoring/install.sh`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/monitoring/install.sh)

- Installs **kube-prometheus-stack**, a single Helm chart that bundles Prometheus (the metrics
  database + scraper), Alertmanager (routes firing alerts), and Grafana (the dashboards UI) —
  instead of installing and wiring up all three separately.
- Generates a random Grafana admin password and stores it in a Kubernetes Secret rather than a
  fixed default — avoids the classic "admin/admin" demo mistake.
- `kubectl apply -k .` applies our own additions on top of the chart: the ServiceMonitors, alert
  rules, and dashboards below — all in the `monitoring` namespace, separate from the app's `shop`
  namespace (per `CLAUDE.md`'s fixed decisions).

### `monitoring/servicemonitor-shop.yaml`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/monitoring/servicemonitor-shop.yaml)

A `ServiceMonitor` is a Custom Resource that the Prometheus Operator (installed by the Helm chart)
watches: it tells Prometheus *which* Kubernetes Services to scrape metrics from. One ServiceMonitor
selects any service in the `shop` namespace labeled `app: web|search|payment` and scrapes its
`/metrics` endpoint every 15 seconds — the exact endpoint the Flask apps expose (Part 1). A second
one does the same for the nginx Prometheus exporter sidecar. Without this file, Prometheus has no
idea our app even exists.

### `monitoring/alerts-shop.yaml`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/monitoring/alerts-shop.yaml)

A `PrometheusRule` with 4 alerts, each a PromQL expression plus a `for:` duration (how long the
condition must stay true before firing, to avoid alerting on a one-second blip):
- **ShopHighErrorRate** — more than 5% of a service's requests are 5xx errors over 5 minutes.
- **ShopPodCrashLooping** — a pod restarted more than twice in 10 minutes.
- **ShopTargetDown** — Prometheus can't scrape a pod at all (it's down or unreachable).
- **ShopHPAMaxedOut** — an HPA has been sitting at its max replica count for 5 minutes straight
  (a signal that `maxReplicas` itself may need raising, not just "it's handling load fine").

### `monitoring/dashboards/generate.py`
[View on GitHub](https://github.com/DevOps-team2-star/Automated-E-Commerce-Deployment-Platform/blob/main/monitoring/dashboards/generate.py)

Generates Grafana dashboard JSON with Python instead of hand-building it by clicking in the
Grafana UI — "dashboards as code". Produces `shop-golden-signals.json` (the four golden signals:
latency, traffic, errors, saturation) and `shop-scaling.json` (HPA replica counts and CPU over
time). The generated JSON files are picked up automatically by Grafana's sidecar container, which
watches for ConfigMaps labeled as dashboards.

## How to demo this part
```bash
cd ~/automated-e-commerce-deployment-platform
bash monitoring/install.sh
bash monitoring/port-forward.sh
```
Open `http://localhost:3000` (Grafana) and `http://localhost:9090` (Prometheus). In Prometheus,
`http://localhost:9090/targets` should show the shop's pods as `UP`.

## 5 questions an instructor might ask

**1. Why kube-prometheus-stack instead of installing Prometheus and Grafana separately?**
It's a maintained, production-grade bundle that already wires Prometheus, Alertmanager, Grafana,
and the Prometheus Operator together correctly (CRDs, RBAC, service discovery) — reinventing that
plumbing by hand is a lot of error-prone YAML for no benefit.

**2. How does Prometheus know to scrape our specific app, out of everything running on the
cluster?**
The `ServiceMonitor` CRD — Prometheus doesn't scrape blindly, it watches for `ServiceMonitor`
objects matching a label selector and only scrapes the Services (and therefore pods) those select.

**3. Why alert on an HPA being "maxed out" — isn't that the HPA working as intended?**
It is working as designed, but it's also a signal: if the HPA is pinned at `maxReplicas` for 5
minutes, the app may genuinely need more headroom (raise `maxReplicas`) or there's a real traffic
spike worth a human looking at — the alert surfaces that instead of it going unnoticed.

**4. Why generate dashboards with a Python script instead of building them in the Grafana UI?**
Dashboards as code are version-controlled, reviewable in a PR, and reproducible — click-built
dashboards live only in one Grafana instance's database and are easy to lose or drift between
environments (local vs AWS).

**5. What's the difference between what Prometheus does and what Grafana does?**
Prometheus scrapes, stores, and evaluates metrics (including firing alerts); Grafana is purely a
visualization layer that queries Prometheus (or other data sources) to draw dashboards — Grafana
stores no metrics itself.
