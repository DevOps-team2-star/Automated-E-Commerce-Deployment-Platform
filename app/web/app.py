"""web service: storefront that calls search and payment.

Provided code. For the CI/CD demo, change STORE_TITLE below, commit and push.
Env vars:
  SEARCH_URL      http://search:8081
  PAYMENT_URL     http://payment:8082
  IMAGE_BASE_URL  e.g. https://<bucket>.s3.eu-central-1.amazonaws.com/images  (optional)
  FAIL_READY      "true" makes /ready return 503 (simulates a bad release for rollback demos)
"""
import os
import time

import requests
from flask import Flask, g, jsonify, redirect, render_template_string, request, url_for
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

STORE_TITLE = "DevOps Team 2 Shop"  # change me to demo a deployment
VERSION = os.environ.get("APP_VERSION", "dev")

SERVICE = "web"
SEARCH_URL = os.environ.get("SEARCH_URL", "http://localhost:8081")
PAYMENT_URL = os.environ.get("PAYMENT_URL", "http://localhost:8082")
IMAGE_BASE_URL = os.environ.get("IMAGE_BASE_URL", "").rstrip("/")
FAIL_READY = os.environ.get("FAIL_READY", "false").lower() == "true"

app = Flask(__name__)

REQUESTS = Counter("http_requests_total", "HTTP requests", ["service", "endpoint", "status"])
LATENCY = Histogram("http_request_duration_seconds", "Request latency", ["service", "endpoint"])

PAGE = """<!doctype html>
<html><head><meta charset="utf-8"><title>{{ title }}</title>
<style>
 body{font-family:system-ui,sans-serif;margin:0;background:#f6f6f4;color:#222}
 header{background:#1f3a5f;color:#fff;padding:16px 24px;display:flex;justify-content:space-between;align-items:center}
 main{max-width:960px;margin:24px auto;padding:0 16px}
 .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:16px}
 .card{background:#fff;border-radius:8px;padding:16px;box-shadow:0 1px 2px rgba(0,0,0,.08)}
 .card img{width:100%;height:120px;object-fit:cover;border-radius:6px;background:#eee}
 .price{font-weight:600;margin:8px 0}
 .msg{padding:12px 16px;border-radius:6px;margin-bottom:16px}
 .ok{background:#e5f4e4}.err{background:#fbebeb}
 form.search{margin-bottom:16px}
 small{color:#666}
</style></head>
<body>
<header><strong>{{ title }}</strong><small style="color:#cfd8e3">version {{ version }}</small></header>
<main>
 {% if message %}<div class="msg {{ 'ok' if ok else 'err' }}">{{ message }}</div>{% endif %}
 <form class="search" method="get" action="/">
  <input name="q" value="{{ q }}" placeholder="Search products"> <button>Search</button>
 </form>
 {% if error %}<div class="msg err">Catalogue unavailable: {{ error }}</div>{% endif %}
 <div class="grid">
 {% for p in products %}
  <div class="card">
   {% if image_base %}<img src="{{ image_base }}/{{ p.image }}" alt="{{ p.name }}">{% endif %}
   <h3>{{ p.name }}</h3>
   <small>{{ p.description }}</small>
   <div class="price">${{ '%.2f' % p.price }} <small>({{ p.stock }} left)</small></div>
   <form method="post" action="/buy">
    <input type="hidden" name="product_id" value="{{ p.id }}">
    <button>Buy</button>
   </form>
  </div>
 {% endfor %}
 </div>
</main></body></html>"""


@app.before_request
def _start_timer():
    g.start = time.time()


@app.after_request
def _record(resp):
    if request.path != "/metrics":
        endpoint = request.url_rule.rule if request.url_rule else "unknown"
        REQUESTS.labels(SERVICE, endpoint, str(resp.status_code)).inc()
        LATENCY.labels(SERVICE, endpoint).observe(time.time() - g.start)
    return resp


@app.get("/health")
def health():
    return jsonify(status="ok", service=SERVICE, version=VERSION)


@app.get("/ready")
def ready():
    if FAIL_READY:
        return jsonify(status="not ready", reason="FAIL_READY=true"), 503
    try:
        requests.get(f"{SEARCH_URL}/health", timeout=2).raise_for_status()
        return jsonify(status="ready")
    except requests.RequestException as exc:
        return jsonify(status="not ready", error=str(exc)), 503


@app.get("/")
def index():
    q = request.args.get("q", "").strip()
    products, error = [], None
    try:
        if q:
            r = requests.get(f"{SEARCH_URL}/search", params={"q": q}, timeout=5)
            r.raise_for_status()
            products = r.json()["results"]
        else:
            r = requests.get(f"{SEARCH_URL}/products", timeout=5)
            r.raise_for_status()
            products = r.json()
    except (requests.RequestException, KeyError, ValueError) as exc:
        error = str(exc)
    status = 200 if error is None else 503
    return (
        render_template_string(
            PAGE,
            title=STORE_TITLE,
            version=VERSION,
            products=products,
            q=q,
            error=error,
            message=request.args.get("msg"),
            ok=request.args.get("ok") == "1",
            image_base=IMAGE_BASE_URL,
        ),
        status,
    )


@app.post("/buy")
def buy():
    product_id = request.form.get("product_id", "0")
    try:
        r = requests.post(f"{PAYMENT_URL}/pay", json={"product_id": product_id, "quantity": 1}, timeout=5)
        data = r.json()
        if r.ok:
            return redirect(url_for("index", msg=f"Order {data['order_id']} paid: ${data['amount']}", ok=1))
        return redirect(url_for("index", msg=f"Payment failed: {data.get('error') or data.get('reason')}"))
    except (requests.RequestException, ValueError) as exc:
        return redirect(url_for("index", msg=f"Payment service unavailable: {exc}"))


@app.get("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
