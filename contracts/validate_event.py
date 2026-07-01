"""Runtime validation of Kafka price events against the shared JSON Schema."""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path

import jsonschema
from jsonschema import Draft202012Validator

SCHEMA_PATH = Path(__file__).resolve().parent / "crypto_price_event.schema.json"


@lru_cache(maxsize=1)
def _validator() -> Draft202012Validator:
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    return Draft202012Validator(schema)


def validate_crypto_price_event(event: dict) -> None:
    """Raise jsonschema.ValidationError if event does not match the contract."""
    _validator().validate(event)


def is_valid_crypto_price_event(event: dict) -> bool:
    try:
        validate_crypto_price_event(event)
        return True
    except jsonschema.ValidationError:
        return False
