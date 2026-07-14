"""Dagster definitions: dbt Software-Defined Assets + Great Expectations + schedule."""

from __future__ import annotations

import os

from dagster import (
    DefaultScheduleStatus,
    Definitions,
    ScheduleDefinition,
    define_asset_job,
)
from dagster_dbt import DbtCliResource

from orchestration.assets import crypto_pulse_dbt_assets
from orchestration.checks import data_quality_checks
from orchestration.project import dbt_project

transform_job = define_asset_job(
    name="transform_job",
    selection="*",
    description="dbt build (run + test per model) -> Great Expectations, as Software-Defined Assets.",
)


def _cron_from_interval_seconds() -> str:
    interval = max(60, int(os.environ.get("TRANSFORM_INTERVAL_SECONDS", "300")))
    minutes = max(1, interval // 60)
    if minutes >= 60:
        hours = max(1, minutes // 60)
        return f"0 */{hours} * * *"
    return f"*/{minutes} * * * *"


transform_schedule = ScheduleDefinition(
    name="transform_schedule",
    job=transform_job,
    cron_schedule=_cron_from_interval_seconds(),
    execution_timezone="UTC",
    default_status=DefaultScheduleStatus.RUNNING,
)

defs = Definitions(
    assets=[crypto_pulse_dbt_assets, data_quality_checks],
    jobs=[transform_job],
    schedules=[transform_schedule],
    resources={
        "dbt": DbtCliResource(project_dir=dbt_project),
    },
)
