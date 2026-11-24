# syntax=docker/dockerfile:1
# ---- build stage: install Python dependencies into /install ----
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- runtime stage: only the app + installed packages, non-root ----
FROM python:3.12-slim
ARG APP_VERSION=dev
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=${APP_VERSION}
RUN useradd --create-home --uid 10001 appuser
WORKDIR /app
COPY --from=builder /install /usr/local
COPY app.py .
USER 10001
EXPOSE 8082
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8082/health', timeout=2)"]
# One worker + threads: prometheus_client keeps metrics per process, so one process keeps counters correct.
# Scale with more pods (HPA), not more workers.
CMD ["gunicorn", "--bind", "0.0.0.0:8082", "--workers", "1", "--threads", "8", "--access-logfile", "-", "app:app"]
