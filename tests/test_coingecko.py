"""Unit tests for CoinGecko event normalization."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ingest"))

from coingecko_normalize import COIN_SYMBOLS, normalize_events


def test_normalize_events_maps_all_tracked_coins() -> None:
    payload = {
        "bitcoin": {"usd": 60000.0, "usd_market_cap": 1.2e12, "usd_24h_change": 1.5},
        "ethereum": {"usd": 1600.0, "usd_market_cap": 2e11, "usd_24h_change": -0.3},
        "solana": {"usd": 75.0, "usd_market_cap": 3e10, "usd_24h_change": 2.1},
    }

    events = normalize_events(payload)

    assert len(events) == 3
    assert {event["coin_id"] for event in events} == {"bitcoin", "ethereum", "solana"}
    for event in events:
        assert event["source"] == "coingecko"
        assert event["symbol"] == COIN_SYMBOLS[event["coin_id"]]
        assert event["price_usd"] > 0
        assert event["event_time"].endswith("+00:00") or "T" in event["event_time"]


def test_normalize_events_preserves_market_fields() -> None:
    events = normalize_events(
        {"bitcoin": {"usd": 1.0, "usd_market_cap": 100.0, "usd_24h_change": -1.0}}
    )

    assert events[0]["market_cap"] == 100.0
    assert events[0]["change_24h"] == -1.0
