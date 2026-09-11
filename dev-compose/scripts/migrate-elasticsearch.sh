#!/usr/bin/env bash
# Copies indices from the live backbone-dev Elasticsearch (3 master + 3 data
# pods, TLS + basic auth) into the local single-node compose Elasticsearch
# (plain HTTP, no auth). Requires: kubectl access to the cluster, node/npx
# (uses elasticdump, fetched on demand - nothing is installed permanently).
#
# Usage:
#   ./scripts/migrate-elasticsearch.sh                 # migrate every index
#   ./scripts/migrate-elasticsearch.sh idx1 idx2 ...    # migrate only these indices
set -euo pipefail

NAMESPACE=backbone-dev
SVC=elasticsearch-master
LOCAL_PORT=9243
TARGET_URL="http://localhost:19200"

echo "==> Fetching ELASTIC_PASSWORD from the live cluster (not written to disk)..."
ELASTIC_PASSWORD=$(kubectl get secret -n "$NAMESPACE" elasticsearch-master-credentials -o jsonpath='{.data.password}' | base64 -d)

echo "==> Port-forwarding $SVC.$NAMESPACE -> localhost:$LOCAL_PORT ..."
kubectl port-forward -n "$NAMESPACE" "svc/$SVC" "$LOCAL_PORT:9200" >/tmp/es-port-forward.log 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT
sleep 3

SOURCE_URL="https://elastic:${ELASTIC_PASSWORD}@localhost:${LOCAL_PORT}"
export NODE_TLS_REJECT_UNAUTHORIZED=0   # source uses a self-signed cluster CA

echo "==> Checking local compose Elasticsearch is up ($TARGET_URL) ..."
curl -sf "$TARGET_URL/_cluster/health" >/dev/null || {
  echo "Local elasticsearch container is not reachable on $TARGET_URL. Start the stack first: docker compose up -d elasticsearch"
  exit 1
}

if [ "$#" -gt 0 ]; then
  INDICES=("$@")
else
  echo "==> Discovering indices on the source cluster..."
  mapfile -t INDICES < <(curl -sk -u "elastic:${ELASTIC_PASSWORD}" "https://localhost:${LOCAL_PORT}/_cat/indices?h=index" | grep -v '^\.' )
fi

echo "==> Will migrate ${#INDICES[@]} index/indices: ${INDICES[*]}"

for idx in "${INDICES[@]}"; do
  echo ""
  echo "---- $idx: mapping ----"
  npx --yes elasticdump \
    --input="${SOURCE_URL}/${idx}" \
    --output="${TARGET_URL}/${idx}" \
    --type=mapping

  echo "---- $idx: data ----"
  npx --yes elasticdump \
    --input="${SOURCE_URL}/${idx}" \
    --output="${TARGET_URL}/${idx}" \
    --type=data \
    --limit=1000
done

echo ""
echo "==> Done. Verify with: curl -s $TARGET_URL/_cat/indices?v"
