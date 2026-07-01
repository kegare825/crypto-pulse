"""Stream Binance trade WebSocket events to Kafka with per-symbol throttling."""

from __future__ import annotations

import asyncio
import json
import logging
import os
import signal
import sys
from typing import Any

import websockets
from confluent_kafka import Producer

from metrics import (
    record_error,
    record_published,
    record_throttled,
    record_trade_received,
    start_metrics_server,
)
from trade_normalize import (
    build_ws_url,
    normalize_trade,
    should_publish,
    unwrap_trade_message,
)
from kafka_producer import build_producer_config

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
    log.info("Shutdown requested...")


def load_config() -> dict[str, str | float | list[str]]:
    streams = [
        stream.strip()
        for stream in os.environ.get(
            "BINANCE_STREAMS",
            "btcusdt@trade,ethusdt@trade,solusdt@trade",
        ).split(",")
        if stream.strip()
    ]
    return {
        "streams": streams,
        "ws_base_url": os.environ.get(
            "BINANCE_WS_BASE_URL",
            "wss://stream.binance.com:9443",
        ),
        "throttle_seconds": float(os.environ.get("BINANCE_THROTTLE_SECONDS", "1")),
        "bootstrap_servers": os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "kafka:9093"),
        "topic": os.environ.get("BINANCE_KAFKA_TOPIC", "binance.trades.raw"),
    }


def publish_event(producer: Producer, topic: str, event: dict[str, Any]) -> None:
    key = f"{event['coin_id']}:{event['source']}".encode("utf-8")
    value = json.dumps(event).encode("utf-8")
    producer.produce(topic=topic, key=key, value=value)
    producer.poll(0)


async def consume_stream(producer: Producer, config: dict[str, str | float | list[str]]) -> None:
    streams = config["streams"]
    if not isinstance(streams, list):
        raise TypeError("streams must be a list")

    url = build_ws_url(str(config["ws_base_url"]), streams)
    throttle = float(config["throttle_seconds"])
    topic = str(config["topic"])

    while running:
        try:
            log.info("Connecting to Binance WebSocket: %s", url)
            async with websockets.connect(url, ping_interval=20, ping_timeout=20) as ws:
                async for raw in ws:
                    if not running:
                        break

                    payload = json.loads(raw)
                    trade = unwrap_trade_message(payload)
                    event = normalize_trade(trade)
                    if event is None:
                        continue

                    coin_id = event["coin_id"]
                    record_trade_received(coin_id)

                    if not should_publish(coin_id, throttle):
                        record_throttled(coin_id)
                        continue

                    publish_event(producer, topic, event)
                    producer.flush(timeout=5)
                    record_published(coin_id, float(event["price_usd"]))
                    log.info(
                        "Published binance %s price_usd=%s",
                        coin_id,
                        event["price_usd"],
                    )
        except asyncio.CancelledError:
            break
        except Exception:
            record_error("ws_disconnect")
            log.exception("Binance WebSocket error, reconnecting in 5s")
            await asyncio.sleep(5)


def main() -> None:
    signal.signal(signal.SIGINT, shutdown_handler)
    signal.signal(signal.SIGTERM, shutdown_handler)

    config = load_config()
    producer = Producer(build_producer_config())
    start_metrics_server()

    log.info(
        "Starting Binance producer topic=%s throttle=%ss streams=%s",
        config["topic"],
        config["throttle_seconds"],
        config["streams"],
    )

    try:
        asyncio.run(consume_stream(producer, config))
    finally:
        producer.flush(timeout=10)
        log.info("Binance producer stopped")


if __name__ == "__main__":
    main()
