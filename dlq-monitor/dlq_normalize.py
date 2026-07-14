"""Pure helpers for parsing dead-lettered Kafka messages."""

from __future__ import annotations

import json
from typing import Any


def parse_dlq_event(raw_bytes: bytes) -> dict[str, Any]:
    """Parse a message produced by the Flink SQL dead-letter sink.

    Never raises: a DLQ monitor that crashes on bad input defeats its own
    purpose. Falls back to a generic "unknown" event on any decode failure.
    """
    try:
        event = json.loads(raw_bytes.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return {
            "source_topic": "unknown",
            "raw_value": None,
            "reason": "dlq_message_undecodable",
            "failed_at": None,
        }

    if not isinstance(event, dict):
        return {
            "source_topic": "unknown",
            "raw_value": None,
            "reason": "dlq_message_not_an_object",
            "failed_at": None,
        }

    return {
        "source_topic": event.get("source_topic") or "unknown",
        "raw_value": event.get("raw_value"),
        "reason": event.get("reason") or "unknown",
        "failed_at": event.get("failed_at"),
    }
