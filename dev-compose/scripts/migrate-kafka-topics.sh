#!/usr/bin/env bash
# Recreates the live backbone-dev Kafka's topics (name, partitions,
# replication factor collapsed to 1) on the local single-node compose Kafka.
#
# Note: this copies topic *definitions*, not historical messages. In this
# platform Kafka is a transient event bus - persister writes the durable
# copy to Postgres (RDS) and the indexer writes to Elasticsearch, so
# consumers rebuild their state from those stores rather than from Kafka
# history. If you specifically need past messages replayed too, use kcat
# (mirror mode) per topic after running this script; see the comment at
# the bottom of this file.
set -euo pipefail

NAMESPACE=backbone-dev
STS=kafka-kraft-controller

echo "==> Listing topics on the live cluster (via kubectl exec into $STS-0)..."
mapfile -t TOPICS < <(kubectl exec -n "$NAMESPACE" "${STS}-0" -c kafka -- \
  kafka-topics.sh --bootstrap-server localhost:9092 --list | grep -vE '^(__consumer_offsets|_schemas)$')

echo "==> ${#TOPICS[@]} topics found."

echo "==> Checking local compose Kafka is up ..."
docker compose exec -T kafka kafka-topics.sh --bootstrap-server localhost:9092 --list >/dev/null || {
  echo "Local kafka container is not reachable. Start the stack first: docker compose up -d kafka"
  exit 1
}

for topic in "${TOPICS[@]}"; do
  PARTITIONS=$(kubectl exec -n "$NAMESPACE" "${STS}-0" -c kafka -- \
    kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic "$topic" \
    | head -1 | grep -oE 'PartitionCount: [0-9]+' | grep -oE '[0-9]+')
  echo "  creating $topic (partitions=$PARTITIONS, replication=1)"
  docker compose exec -T kafka kafka-topics.sh --bootstrap-server localhost:9092 \
    --create --if-not-exists --topic "$topic" --partitions "${PARTITIONS:-1}" --replication-factor 1 >/dev/null
done

echo "==> Done. Verify with: docker compose exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list"
echo ""
echo "To also replay historical messages for a specific topic (optional, rarely needed):"
echo "  kubectl port-forward -n $NAMESPACE svc/kafka-kraft 19093:9092 &"
echo "  kcat -b localhost:19093 -t <topic> -C -o beginning -e | kcat -b localhost:19092 -t <topic> -P"
