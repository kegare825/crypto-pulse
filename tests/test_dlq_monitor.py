"""Unit tests for dead-letter message parsing."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "dlq-monitor"))

from dlq_normalize import parse_dlq_event  # noqa: E402


def test_parse_dlq_event_well_formed() -> None:
    raw = (
        b'{"source_topic": "coingecko.prices.raw", "raw_value": "{bad json", '
        b'"reason": "invalid_json_or_missing_coin_id", '
        b'"failed_at": "2026-01-01T00:00:00Z"}'
    )
    event = parse_dlq_event(raw)
    assert event["source_topic"] == "coingecko.prices.raw"
    assert event["reason"] == "invalid_json_or_missing_coin_id"
    assert event["raw_value"] == "{bad json"
    assert event["failed_at"] == "2026-01-01T00:00:00Z"


def test_parse_dlq_event_handles_undecodable_bytes() -> None:
    event = parse_dlq_event(b"\xff\xfe\x00\x01not valid utf-8")
    assert event["source_topic"] == "unknown"
    assert event["reason"] == "dlq_message_undecodable"


def test_parse_dlq_event_handles_non_json_bytes() -> None:
    event = parse_dlq_event(b"not json at all")
    assert event["source_topic"] == "unknown"
    assert event["reason"] == "dlq_message_undecodable"


def test_parse_dlq_event_handles_json_array_payload() -> None:
    event = parse_dlq_event(b"[1, 2, 3]")
    assert event["source_topic"] == "unknown"
    assert event["reason"] == "dlq_message_not_an_object"


def test_parse_dlq_event_defaults_missing_fields() -> None:
    event = parse_dlq_event(b"{}")
    assert event["source_topic"] == "unknown"
    assert event["reason"] == "unknown"
    assert event["raw_value"] is None
