# Nginx reverse proxy image used by docker compose (Kubernetes mounts the same file from a ConfigMap).
FROM nginxinc/nginx-unprivileged:stable-alpine
COPY default.conf /etc/nginx/conf.d/default.conf
COPY 50x.html /usr/share/nginx/html/50x.html
EXPOSE 8080
