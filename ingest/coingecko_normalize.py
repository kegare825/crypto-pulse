"""Pure normalization helpers for CoinGecko API payloads."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

COIN_SYMBOLS: dict[str, str] = {
    "bitcoin": "btc",
    "ethereum": "eth",
    "solana": "sol",
}


def normalize_events(payload: dict[str, Any]) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    event_time = datetime.now(timezone.utc).isoformat()

    for coin_id, values in payload.items():
        events.append(
            {
                "coin_id": coin_id,
                "symbol": COIN_SYMBOLS.get(coin_id, coin_id),
                "price_usd": values.get("usd"),
                "market_cap": values.get("usd_market_cap"),
                "change_24h": values.get("usd_24h_change"),
                "event_time": event_time,
                "source": "coingecko",
            }
        )
    return events
