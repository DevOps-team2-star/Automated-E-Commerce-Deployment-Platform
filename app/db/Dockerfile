# Postgres with the shop schema + seed baked in (no bind mount needed, so it also works when
# Jenkins drives Docker through the host socket).
FROM postgres:16-alpine
COPY init.sql /docker-entrypoint-initdb.d/init.sql
