"""Dagster ops: dbt run → dbt test → Great Expectations."""

from __future__ import annotations

import os
import subprocess

from dagster import In, Nothing, op

DBT_DIR = os.environ.get("DBT_PROJECT_DIR", "/app/dbt")
VALIDATE_SCRIPT = os.environ.get("GE_VALIDATE_SCRIPT", "/app/validate.py")
DBT_ARGS = ["--profiles-dir", DBT_DIR]


def _run(cmd: list[str], *, cwd: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=cwd,
        check=True,
        capture_output=True,
        text=True,
    )


@op
def dbt_run_op(context) -> None:
    """Install dbt packages and build silver/gold models."""
    _run(["dbt", "deps", *DBT_ARGS], cwd=DBT_DIR)
    result = _run(["dbt", "run", *DBT_ARGS], cwd=DBT_DIR)
    context.log.info(result.stdout[-4000:])


@op(ins={"after_run": In(Nothing)})
def dbt_test_op(context) -> None:
    """Run dbt schema and data tests."""
    result = _run(["dbt", "test", *DBT_ARGS], cwd=DBT_DIR)
    context.log.info(result.stdout[-2000:])


@op(ins={"after_test": In(Nothing)})
def great_expectations_op(context) -> None:
    """Cross-zone Great Expectations validation."""
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
