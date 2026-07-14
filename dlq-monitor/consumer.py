"""Watch the dead-letter topic, log rejected payloads, expose Prometheus metrics."""

from __future__ import annotations

import logging
import os
import sys
from typing import Any

from confluent_kafka import Consumer, KafkaException

from dlq_normalize import parse_dlq_event
from metrics import record_dlq_message, start_metrics_server

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger(__name__)

running = True


def shutdown_handler(_signum: int, _frame: Any) -> None:
    global running
    running = False
    log.info("Shutdown requested, stopping DLQ monitor...")


def main() -> None:
    import signal

    signal.signal(signal.SIGINT, shutdown_handler)
    signal.signal(signal.SIGTERM, shutdown_handler)

    bootstrap_servers = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "kafka:9093")
    topic = os.environ.get("KAFKA_DLQ_TOPIC", "crypto-pulse.dlq")
    group_id = os.environ.get("KAFKA_DLQ_CONSUMER_GROUP", "crypto-pulse-dlq-monitor")

    start_metrics_server()

    consumer = Consumer(
        {
            "bootstrap.servers": bootstrap_servers,
            "group.id": group_id,
            "auto.offset.reset": "earliest",
            "enable.auto.commit": True,
        }
    )
    consumer.subscribe([topic])
    log.info("Watching dead-letter topic '%s' via %s", topic, bootstrap_servers)

    try:
        while running:
            message = consumer.poll(1.0)
            if message is None:
                continue
            if message.error():
                raise KafkaException(message.error())

            event = parse_dlq_event(message.value())
            record_dlq_message(event["source_topic"], event["reason"])
            log.warning(
                "Dead-lettered message source=%s reason=%s raw=%s",
                event["source_topic"],
                event["reason"],
                (event["raw_value"] or "")[:200],
            )
    finally:
        consumer.close()
        log.info("DLQ monitor stopped")


if __name__ == "__main__":
    main()
