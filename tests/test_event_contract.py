"""Validate sample events against the shared JSON Schema contract."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import jsonschema
import pytest
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "ingest"))
sys.path.insert(0, str(ROOT / "binance-ingest"))

from coingecko_normalize import normalize_events
import trade_normalize as bn

SCHEMA_PATH = ROOT / "contracts" / "crypto_price_event.schema.json"
SCHEMA = json.loads(SCHEMA_PATH.read_text())
VALIDATOR = Draft202012Validator(SCHEMA)


@pytest.fixture
def coingecko_event() -> dict:
    return normalize_events(
        {"bitcoin": {"usd": 60000.0, "usd_market_cap": 1e12, "usd_24h_change": 1.0}}
    )[0]


@pytest.fixture
def binance_event() -> dict:
    event = bn.normalize_trade(
        {"e": "trade", "s": "SOLUSDT", "p": "75.5", "T": 1_700_000_000_000}
    )
    assert event is not None
    return event


@pytest.mark.parametrize("source", ["coingecko", "binance"])
def test_sample_events_match_contract(source: str, coingecko_event: dict, binance_event: dict) -> None:
    event = coingecko_event if source == "coingecko" else binance_event
    VALIDATOR.validate(event)


def test_contract_rejects_missing_source() -> None:
    with pytest.raises(jsonschema.ValidationError):
        VALIDATOR.validate(
            {
                "coin_id": "bitcoin",
                "symbol": "btc",
                "price_usd": 1.0,
                "market_cap": None,
                "change_24h": None,
                "event_time": "2026-06-29T12:00:00+00:00",
            }
        )
