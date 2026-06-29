"""Shared pytest fixtures — adds ingest paths per test module."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _prepend(path: Path) -> None:
    value = str(path)
    if value not in sys.path:
        sys.path.insert(0, value)


def pytest_configure(config) -> None:
    # Default: repo root for contract tests that import both modules explicitly.
    _prepend(ROOT / "ingest")
    _prepend(ROOT / "binance-ingest")
