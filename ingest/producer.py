"""Poll CoinGecko and publish price events to Kafka."""

from __future__ import annotations

import json
import logging
import os
import signal
import sys
import time
from typing import Any

import httpx
from confluent_kafka import Producer

from metrics import record_error, record_success, start_metrics_server
from coingecko_normalize import normalize_events

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
    log.info("Shutdown requested, finishing current cycle...")


def load_config() -> dict[str, str | int | list[str]]:
    coin_ids = [
        coin.strip()
        for coin in os.environ.get("COINGECKO_COIN_IDS", "bitcoin,ethereum,solana").split(",")
        if coin.strip()
    ]
    return {
        "api_url": os.environ.get(
            "COINGECKO_API_URL",
            "https://api.coingecko.com/api/v3/simple/price",
        ),
        "coin_ids": coin_ids,
        "poll_interval": int(os.environ.get("POLL_INTERVAL_SECONDS", "60")),
        "bootstrap_servers": os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "kafka:9093"),
        "topic": os.environ.get("KAFKA_TOPIC", "coingecko.prices.raw"),
    }


def fetch_prices(client: httpx.Client, api_url: str, coin_ids: list[str]) -> dict[str, Any]:
    params = {
        "ids": ",".join(coin_ids),
        "vs_currencies": "usd",
        "include_market_cap": "true",
        "include_24hr_change": "true",
    }
    response = client.get(api_url, params=params)
    response.raise_for_status()
    return response.json()


def delivery_report(err: Exception | None, msg: Any) -> None:
    if err is not None:
        log.error("Failed to deliver message to %s: %s", msg.topic(), err)
        return
    log.debug(
        "Delivered to %s partition %s offset %s",
        msg.topic(),
        msg.partition(),
        msg.offset(),
    )


def publish_events(producer: Producer, topic: str, events: list[dict[str, Any]]) -> None:
    for event in events:
        key = event["coin_id"].encode("utf-8")
        value = json.dumps(event).encode("utf-8")
        producer.produce(
            topic=topic,
            key=key,
            value=value,
            callback=delivery_report,
        )
    producer.flush(timeout=10)


def run_cycle(
    client: httpx.Client,
    producer: Producer,
    config: dict[str, str | int | list[str]],
) -> None:
    coin_ids = config["coin_ids"]
    if not isinstance(coin_ids, list):
        raise TypeError("coin_ids must be a list")

    payload = fetch_prices(client, str(config["api_url"]), coin_ids)
    events = normalize_events(payload)
    publish_events(producer, str(config["topic"]), events)
    record_success(events)

    for event in events:
        log.info(
            "Published %s price_usd=%s change_24h=%s",
            event["coin_id"],
            event["price_usd"],
            event["change_24h"],
        )


def main() -> None:
    signal.signal(signal.SIGINT, shutdown_handler)
    signal.signal(signal.SIGTERM, shutdown_handler)

    config = load_config()
    producer = Producer({"bootstrap.servers": str(config["bootstrap_servers"])})
    start_metrics_server()

    log.info(
        "Starting CoinGecko producer topic=%s interval=%ss coins=%s",
        config["topic"],
        config["poll_interval"],
        config["coin_ids"],
    )

    with httpx.Client(timeout=15.0) as client:
        while running:
            started = time.monotonic()
            try:
                run_cycle(client, producer, config)
            except httpx.HTTPStatusError as exc:
                record_error("http_status")
                log.error(
                    "CoinGecko API error status=%s body=%s",
                    exc.response.status_code,
                    exc.response.text[:200],
                )
            except Exception:
                record_error("unexpected")
                log.exception("Unexpected error during ingest cycle")

            elapsed = time.monotonic() - started
            sleep_for = max(0.0, float(config["poll_interval"]) - elapsed)
            if running and sleep_for > 0:
                time.sleep(sleep_for)

    log.info("Producer stopped")


if __name__ == "__main__":
    main()
