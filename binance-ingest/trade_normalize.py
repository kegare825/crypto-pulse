"""Pure normalization helpers for Binance trade WebSocket payloads."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

SYMBOL_TO_COIN: dict[str, tuple[str, str]] = {
    "BTCUSDT": ("bitcoin", "btc"),
    "ETHUSDT": ("ethereum", "eth"),
    "SOLUSDT": ("solana", "sol"),
}

last_published_at: dict[str, float] = {}


def build_ws_url(ws_base_url: str, streams: list[str]) -> str:
    if not streams:
        raise ValueError("BINANCE_STREAMS must contain at least one stream")

    if len(streams) == 1:
        return f"{ws_base_url}/ws/{streams[0]}"

    joined = "/".join(streams)
    return f"{ws_base_url}/stream?streams={joined}"


def unwrap_trade_message(payload: dict[str, Any]) -> dict[str, Any]:
    if "data" in payload and isinstance(payload["data"], dict):
        return payload["data"]
    return payload


def normalize_trade(trade: dict[str, Any]) -> dict[str, Any] | None:
    if trade.get("e") != "trade":
        return None

    symbol = str(trade.get("s", "")).upper()
    mapping = SYMBOL_TO_COIN.get(symbol)
    if mapping is None:
        return None

    coin_id, coin_symbol = mapping
    trade_time_ms = trade.get("T")
    if trade_time_ms is None:
        return None

    event_time = datetime.fromtimestamp(trade_time_ms / 1000, tz=timezone.utc).isoformat()
    return {
        "coin_id": coin_id,
        "symbol": coin_symbol,
        "price_usd": float(trade["p"]),
        "market_cap": None,
        "change_24h": None,
        "event_time": event_time,
        "source": "binance",
    }


def should_publish(coin_id: str, throttle_seconds: float) -> bool:
    import time

    now = time.monotonic()
    last = last_published_at.get(coin_id, 0.0)
    if now - last < throttle_seconds:
        return False
    last_published_at[coin_id] = now
    return True
