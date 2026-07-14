#!/usr/bin/env bash
# Pre-create Kafka topics with explicit retention (survives broker restarts when using kafka_data volume).
set -euo pipefail

BOOTSTRAP="${KAFKA_BOOTSTRAP_SERVER:-localhost:9092}"
RETENTION_MS="${KAFKA_TOPIC_RETENTION_MS:-604800000}"
PARTITIONS="${KAFKA_TOPIC_PARTITIONS:-3}"
REPLICATION="${KAFKA_TOPIC_REPLICATION_FACTOR:-1}"

create_topic() {
    local topic="$1"
    echo "Ensuring topic ${topic} (partitions=${PARTITIONS}, retention.ms=${RETENTION_MS})"
    /opt/kafka/bin/kafka-topics.sh --create --if-not-exists \
        --bootstrap-server "${BOOTSTRAP}" \
        --topic "${topic}" \
        --partitions "${PARTITIONS}" \
        --replication-factor "${REPLICATION}" \
        --config "retention.ms=${RETENTION_MS}" \
        --config "min.insync.replicas=1"
}

create_topic "coingecko.prices.raw"
create_topic "binance.trades.raw"
create_topic "${KAFKA_DLQ_TOPIC:-crypto-pulse.dlq}"

echo "Kafka topics ready"
