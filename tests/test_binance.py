"""Unit tests for Binance trade normalization and throttling."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "binance-ingest"))
sys.path.insert(0, str(ROOT / "contracts"))

import trade_normalize as bn


def setup_function() -> None:
    bn.last_published_at.clear()


def test_build_ws_url_single_stream() -> None:
    url = bn.build_ws_url("wss://stream.binance.com:9443", ["btcusdt@trade"])
    assert url == "wss://stream.binance.com:9443/ws/btcusdt@trade"


def test_build_ws_url_combined_stream() -> None:
    url = bn.build_ws_url(
        "wss://stream.binance.com:9443",
        ["btcusdt@trade", "ethusdt@trade"],
    )
    assert url == "wss://stream.binance.com:9443/stream?streams=btcusdt@trade/ethusdt@trade"


def test_normalize_trade_maps_btcusdt() -> None:
    event = bn.normalize_trade(
        {
            "e": "trade",
            "s": "BTCUSDT",
            "p": "60000.50",
            "T": 1_700_000_000_000,
        }
    )

    assert event is not None
    assert event["coin_id"] == "bitcoin"
    assert event["symbol"] == "btc"
    assert event["source"] == "binance"
    assert event["price_usd"] == 60000.50
    assert event["market_cap"] is None


def test_normalize_trade_ignores_unknown_symbol() -> None:
    assert bn.normalize_trade({"e": "trade", "s": "DOGEUSDT", "p": "1", "T": 1}) is None


def test_normalize_trade_ignores_non_trade_events() -> None:
    assert bn.normalize_trade({"e": "depthUpdate"}) is None


def test_should_publish_respects_throttle() -> None:
    assert bn.should_publish("bitcoin", throttle_seconds=10.0) is True
    assert bn.should_publish("bitcoin", throttle_seconds=10.0) is False
    assert bn.should_publish("ethereum", throttle_seconds=10.0) is True


def test_unwrap_trade_message_combined_stream_payload() -> None:
    inner = {"e": "trade", "s": "ETHUSDT", "p": "1600", "T": 1}
    assert bn.unwrap_trade_message({"stream": "ethusdt@trade", "data": inner}) == inner
