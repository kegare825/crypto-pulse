"""Dagster job and schedule for the transform pipeline."""

from __future__ import annotations

import os

from dagster import DefaultScheduleStatus, Definitions, ScheduleDefinition, job

from orchestration.assets import dbt_run_op, dbt_test_op, great_expectations_op


@job(description="dbt run → dbt test → Great Expectations")
def transform_job() -> None:
    run = dbt_run_op()
    test = dbt_test_op(after_run=run)
    great_expectations_op(after_test=test)


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
    jobs=[transform_job],
    schedules=[transform_schedule],
)
