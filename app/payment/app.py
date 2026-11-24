"""payment service: mock card payment that records orders in PostgreSQL.

Provided code. You do not need to change it for the DevOps project.
Env vars:
  DATABASE_URL   postgresql://user:pass@host:5432/shop
  ERROR_RATE     0.0-1.0 share of requests that fail with HTTP 500 (rollback / alert demos)
A card number ending in 0000 is always declined (business failure, HTTP 402).
"""
import os
import random
import time

import psycopg2
import psycopg2.extras
from flask import Flask, g, jsonify, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

SERVICE = "payment"
DB_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:shop@localhost:5432/shop")
ERROR_RATE = float(os.environ.get("ERROR_RATE", "0"))

app = Flask(__name__)

REQUESTS = Counter("http_requests_total", "HTTP requests", ["service", "endpoint", "status"])
LATENCY = Histogram("http_request_duration_seconds", "Request latency", ["service", "endpoint"])
ORDERS = Counter("shop_orders_total", "Orders paid successfully")
FAILURES = Counter("shop_payment_failures_total", "Failed payments", ["reason"])


def connect():
    return psycopg2.connect(DB_URL, connect_timeout=3)


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
        conn = connect()
        conn.close()
        return jsonify(status="ready")
    except Exception as exc:  # noqa: BLE001
        return jsonify(status="not ready", error=str(exc)), 503


@app.post("/pay")
def pay():
    if ERROR_RATE and random.random() < ERROR_RATE:
        FAILURES.labels("injected_error").inc()
        return jsonify(error="injected failure (ERROR_RATE)"), 500

    body = request.get_json(silent=True) or {}
    try:
        product_id = int(body.get("product_id", 0))
        quantity = max(1, int(body.get("quantity", 1)))
    except (TypeError, ValueError):
        FAILURES.labels("bad_request").inc()
        return jsonify(error="product_id and quantity must be numbers"), 400
    card = str(body.get("card", "4242424242424242"))

    if card.endswith("0000"):
        FAILURES.labels("card_declined").inc()
        return jsonify(status="declined", reason="card declined"), 402

    try:
        conn = connect()
        try:
            with conn, conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("SELECT price, stock FROM products WHERE id = %s FOR UPDATE", (product_id,))
                row = cur.fetchone()
                if not row:
                    FAILURES.labels("unknown_product").inc()
                    return jsonify(error="unknown product"), 404
                if row["stock"] < quantity:
                    FAILURES.labels("out_of_stock").inc()
                    return jsonify(error="out of stock"), 409
                amount = float(row["price"]) * quantity
                cur.execute("UPDATE products SET stock = stock - %s WHERE id = %s", (quantity, product_id))
                cur.execute(
                    "INSERT INTO orders (product_id, quantity, amount) VALUES (%s, %s, %s) RETURNING id",
                    (product_id, quantity, amount),
                )
                order_id = cur.fetchone()["id"]
        finally:
            conn.close()
    except Exception as exc:  # noqa: BLE001
        FAILURES.labels("database").inc()
        return jsonify(error=str(exc)), 503

    ORDERS.inc()
    return jsonify(status="paid", order_id=order_id, amount=round(amount, 2))


@app.get("/orders")
def orders():
    try:
        conn = connect()
        try:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(
                    "SELECT o.id, p.name, o.quantity, o.amount, o.created_at FROM orders o "
                    "JOIN products p ON p.id = o.product_id ORDER BY o.id DESC LIMIT 20"
                )
                rows = cur.fetchall()
        finally:
            conn.close()
    except Exception as exc:  # noqa: BLE001
        return jsonify(error=str(exc)), 503
    for r in rows:
        r["amount"] = float(r["amount"])
        r["created_at"] = r["created_at"].isoformat()
    return jsonify(rows)


@app.get("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8082)
