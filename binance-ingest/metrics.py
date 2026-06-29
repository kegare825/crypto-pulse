"""Prometheus metrics for the Binance WebSocket ingest."""

from __future__ import annotations

import os

from prometheus_client import Counter, Gauge, start_http_server

MESSAGES_PUBLISHED = Counter(
    "crypto_pulse_binance_messages_published_total",
    "Throttled Binance trade messages published to Kafka",
    ["coin_id"],
)
TRADES_RECEIVED = Counter(
    "crypto_pulse_binance_trades_received_total",
    "Raw Binance trades received from WebSocket",
    ["coin_id"],
)
TRADES_THROTTLED = Counter(
    "crypto_pulse_binance_trades_throttled_total",
    "Binance trades dropped by throttle",
    ["coin_id"],
)
WS_ERRORS = Counter(
    "crypto_pulse_binance_ws_errors_total",
    "Binance WebSocket or publish errors",
    ["error_type"],
)
LAST_PRICE = Gauge(
    "crypto_pulse_binance_last_price_usd",
    "Last throttled Binance price published",
    ["coin_id"],
)


def start_metrics_server() -> None:
    port = int(os.environ.get("METRICS_PORT", "8001"))
    start_http_server(port)
    print(f"Binance metrics listening on :{port}/metrics", flush=True)


def record_trade_received(coin_id: str) -> None:
    TRADES_RECEIVED.labels(coin_id=coin_id).inc()


def record_throttled(coin_id: str) -> None:
    TRADES_THROTTLED.labels(coin_id=coin_id).inc()


def record_published(coin_id: str, price_usd: float) -> None:
    MESSAGES_PUBLISHED.labels(coin_id=coin_id).inc()
    LAST_PRICE.labels(coin_id=coin_id).set(price_usd)


def record_error(error_type: str) -> None:
    WS_ERRORS.labels(error_type=error_type).inc()
