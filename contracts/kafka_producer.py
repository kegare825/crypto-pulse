"""Shared Confluent Kafka producer settings for resilient publish."""

from __future__ import annotations

import os


def build_producer_config() -> dict[str, str | int | bool]:
    """Durable producer defaults: idempotence, acks=all, retries."""
    return {
        "bootstrap.servers": os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "kafka:9093"),
        "acks": "all",
        "enable.idempotence": True,
        "retries": int(os.environ.get("KAFKA_PRODUCER_RETRIES", "10")),
        "delivery.timeout.ms": int(os.environ.get("KAFKA_DELIVERY_TIMEOUT_MS", "120000")),
        "request.timeout.ms": int(os.environ.get("KAFKA_REQUEST_TIMEOUT_MS", "30000")),
        "socket.keepalive.enable": True,
        "reconnect.backoff.max.ms": int(
            os.environ.get("KAFKA_RECONNECT_BACKOFF_MAX_MS", "10000")
        ),
        "message.timeout.ms": int(os.environ.get("KAFKA_MESSAGE_TIMEOUT_MS", "120000")),
    }
