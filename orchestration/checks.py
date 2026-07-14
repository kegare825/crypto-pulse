"""Great Expectations as a Software-Defined Asset, downstream of every dbt model.

No `from __future__ import annotations` here either — see the note in
assets.py; it breaks Dagster's `context: AssetExecutionContext` validation.
"""

import os
import subprocess

from dagster import AssetExecutionContext, asset

from orchestration.assets import crypto_pulse_dbt_assets

VALIDATE_SCRIPT = os.environ.get("GE_VALIDATE_SCRIPT", "/app/validate.py")


@asset(
    deps=[crypto_pulse_dbt_assets],
    group_name="quality",
    description="Cross-zone Great Expectations checks (raw/silver/gold) — see docs/SLA.md.",
)
def data_quality_checks(context: AssetExecutionContext) -> None:
    result = subprocess.run(
        ["python", VALIDATE_SCRIPT],
        capture_output=True,
        text=True,
    )
    context.log.info(result.stdout)
    if result.returncode != 0:
        raise RuntimeError(
            f"Great Expectations failed (exit {result.returncode}):\n"
            f"{result.stdout}\n{result.stderr}"
        )
