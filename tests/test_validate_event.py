"""Tests for runtime JSON Schema validation."""

from __future__ import annotations

import sys
from pathlib import Path

import jsonschema
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "contracts"))

from validate_event import is_valid_crypto_price_event, validate_crypto_price_event


def test_valid_coingecko_event() -> None:
    event = {
        "coin_id": "bitcoin",
        "symbol": "btc",
        "price_usd": 60000.0,
        "market_cap": 1e12,
        "change_24h": 1.0,
        "event_time": "2026-06-29T12:00:00+00:00",
        "source": "coingecko",
    }
    validate_crypto_price_event(event)
    assert is_valid_crypto_price_event(event)


def test_rejects_missing_source() -> None:
    with pytest.raises(jsonschema.ValidationError):
        validate_crypto_price_event(
            {
                "coin_id": "bitcoin",
                "symbol": "btc",
                "price_usd": 1.0,
                "market_cap": None,
                "change_24h": None,
                "event_time": "2026-06-29T12:00:00+00:00",
            }
        )


def test_rejects_zero_price() -> None:
    with pytest.raises(jsonschema.ValidationError):
        validate_crypto_price_event(
            {
                "coin_id": "bitcoin",
                "symbol": "btc",
                "price_usd": 0,
                "market_cap": None,
                "change_24h": None,
                "event_time": "2026-06-29T12:00:00+00:00",
                "source": "binance",
            }
        )
