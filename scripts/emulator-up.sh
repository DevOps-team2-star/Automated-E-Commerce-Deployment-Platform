#!/usr/bin/env bash
# Starts a local AWS emulator on http://localhost:4566 (container name: aws-emulator).
#   ./scripts/emulator-up.sh                  -> MiniStack (MIT, no account needed)
#   EMULATOR=localstack LOCALSTACK_AUTH_TOKEN=... ./scripts/emulator-up.sh
#                                             -> LocalStack (free Hobby account + token; no RDS/ALB on Hobby)
# The container joins the k3d-shop network (if it exists) so Jenkins reaches it at http://aws-emulator:4566.
set -euo pipefail
EMULATOR=${EMULATOR:-ministack}
NAME=aws-emulator
CLUSTER=${CLUSTER:-shop}

case "$EMULATOR" in
  ministack)  IMAGE=${EMULATOR_IMAGE:-ministackorg/ministack:latest}; EXTRA=() ;;
  localstack) IMAGE=${EMULATOR_IMAGE:-localstack/localstack:latest}
              : "${LOCALSTACK_AUTH_TOKEN:?LocalStack needs LOCALSTACK_AUTH_TOKEN (free Hobby account at app.localstack.cloud)}"
              EXTRA=(-e "LOCALSTACK_AUTH_TOKEN=$LOCALSTACK_AUTH_TOKEN") ;;
  *) echo "EMULATOR must be ministack or localstack"; exit 1 ;;
esac

if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "==> Removing old $NAME container"; docker rm -f "$NAME" >/dev/null
fi

NET=()
docker network inspect "k3d-$CLUSTER" >/dev/null 2>&1 && NET=(--network "k3d-$CLUSTER")

echo "==> Starting $EMULATOR ($IMAGE)"
# The Docker socket lets the emulator start real Postgres containers for RDS.
docker run -d --name "$NAME" --restart unless-stopped \
  -p 4566:4566 "${NET[@]}" "${EXTRA[@]}" \
  -e AWS_DEFAULT_REGION=eu-central-1 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  "$IMAGE" >/dev/null

echo "==> Waiting for the emulator to answer"
export AWS_ACCESS_KEY_ID=000000000000 AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=eu-central-1
for _ in $(seq 1 60); do
  if aws --endpoint-url http://localhost:4566 sts get-caller-identity >/dev/null 2>&1; then
    aws --endpoint-url http://localhost:4566 sts get-caller-identity --output table
    echo "Emulator ready: http://localhost:4566 (from Jenkins: http://$NAME:4566)"
    exit 0
  fi
  sleep 2
done
echo "Emulator did not answer in time:"; docker logs --tail 40 "$NAME"; exit 1
