"""Prometheus metrics for the dead-letter queue monitor."""

from __future__ import annotations

import os

from prometheus_client import Counter, Gauge, start_http_server

DLQ_MESSAGES = Counter(
    "crypto_pulse_dlq_messages_total",
    "Dead-lettered messages consumed, by source topic and reason",
    ["source_topic", "reason"],
)
LAST_DLQ_UNIXTIME = Gauge(
    "crypto_pulse_last_dlq_message_timestamp",
    "Unix timestamp of the last dead-lettered message observed",
)


def start_metrics_server() -> None:
    port = int(os.environ.get("METRICS_PORT", "8002"))
    start_http_server(port)
    print(f"Prometheus metrics listening on :{port}/metrics", flush=True)


def record_dlq_message(source_topic: str, reason: str) -> None:
    DLQ_MESSAGES.labels(source_topic=source_topic, reason=reason).inc()
    LAST_DLQ_UNIXTIME.set_to_current_time()
