"""Prometheus metrics for the CoinGecko ingest producer."""

from __future__ import annotations

import os

from prometheus_client import Counter, Gauge, start_http_server

MESSAGES_PUBLISHED = Counter(
    "crypto_pulse_messages_published_total",
    "Total Kafka messages published by coin",
    ["coin_id"],
)
EVENTS_PER_CYCLE = Counter(
    "crypto_pulse_ingest_cycles_total",
    "Successful ingest poll cycles",
)
API_ERRORS = Counter(
    "crypto_pulse_api_errors_total",
    "CoinGecko API or publish errors",
    ["error_type"],
)
LAST_POLL_UNIXTIME = Gauge(
    "crypto_pulse_last_successful_poll_timestamp",
    "Unix timestamp of last successful poll",
)
LAST_BTC_PRICE = Gauge(
    "crypto_pulse_last_price_usd",
    "Last published USD price by coin",
    ["coin_id"],
)


def start_metrics_server() -> None:
    port = int(os.environ.get("METRICS_PORT", "8000"))
    start_http_server(port)
    print(f"Prometheus metrics listening on :{port}/metrics", flush=True)


def record_success(events: list[dict]) -> None:
    EVENTS_PER_CYCLE.inc()
    LAST_POLL_UNIXTIME.set_to_current_time()
    for event in events:
        coin_id = event["coin_id"]
        MESSAGES_PUBLISHED.labels(coin_id=coin_id).inc()
        if event.get("price_usd") is not None:
            LAST_BTC_PRICE.labels(coin_id=coin_id).set(float(event["price_usd"]))


def record_error(error_type: str) -> None:
    API_ERRORS.labels(error_type=error_type).inc()
