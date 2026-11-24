"""search service: product catalogue and search, backed by PostgreSQL.

Provided code. You do not need to change it for the DevOps project.
Env vars:
  DATABASE_URL   postgresql://user:pass@host:5432/shop
  CPU_WORK       extra hashing per request so the HPA demo shows CPU load (default 2000)
"""
import hashlib
import os
import time

import psycopg2
import psycopg2.extras
from flask import Flask, g, jsonify, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

SERVICE = "search"
DB_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:shop@localhost:5432/shop")
CPU_WORK = int(os.environ.get("CPU_WORK", "2000"))

app = Flask(__name__)

REQUESTS = Counter("http_requests_total", "HTTP requests", ["service", "endpoint", "status"])
LATENCY = Histogram("http_request_duration_seconds", "Request latency", ["service", "endpoint"])


def db_query(sql, params=()):
    conn = psycopg2.connect(DB_URL, connect_timeout=3)
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params)
            rows = cur.fetchall()
            for r in rows:
                if "price" in r and r["price"] is not None:
                    r["price"] = float(r["price"])
            return rows
    finally:
        conn.close()


def burn_cpu():
    h = b"shop"
    for _ in range(CPU_WORK):
        h = hashlib.sha256(h).digest()


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
    return jsonify(status="ok", service=SERVICE)


@app.get("/ready")
def ready():
    try:
        db_query("SELECT 1 AS ok")
        return jsonify(status="ready")
    except Exception as exc:  # noqa: BLE001
        return jsonify(status="not ready", error=str(exc)), 503


@app.get("/products")
def products():
    burn_cpu()
    try:
        return jsonify(db_query("SELECT id, name, description, price, image, stock FROM products ORDER BY id"))
    except Exception as exc:  # noqa: BLE001
        return jsonify(error=str(exc)), 503


@app.get("/products/<int:product_id>")
def product(product_id):
    try:
        rows = db_query("SELECT id, name, description, price, image, stock FROM products WHERE id = %s", (product_id,))
    except Exception as exc:  # noqa: BLE001
        return jsonify(error=str(exc)), 503
    return (jsonify(rows[0]), 200) if rows else (jsonify(error="not found"), 404)


@app.get("/search")
def search():
    burn_cpu()
    q = request.args.get("q", "").strip()
    try:
        rows = db_query(
            "SELECT id, name, description, price, image, stock FROM products "
            "WHERE name ILIKE %s OR description ILIKE %s ORDER BY id",
            (f"%{q}%", f"%{q}%"),
        )
    except Exception as exc:  # noqa: BLE001
        return jsonify(error=str(exc)), 503
    return jsonify(query=q, count=len(rows), results=rows)


@app.get("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081)
