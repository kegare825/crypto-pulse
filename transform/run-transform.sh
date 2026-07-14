#!/usr/bin/env bash
# One-off transform cycle (same assets as Dagster schedule). Prefer Dagster UI on :3002.
# Standalone entrypoint (docker compose run --rm transform /app/run-transform.sh
# bypasses entrypoint.sh), so it prepares its own dbt manifest before Dagster
# imports orchestration.definitions.
set -euo pipefail

export DAGSTER_HOME="${DAGSTER_HOME:-/tmp/dagster}"
export PYTHONPATH="${PYTHONPATH:-/app}"
mkdir -p "${DAGSTER_HOME}"

(cd /app/dbt && dbt deps --profiles-dir . && dbt parse --profiles-dir .)

dagster job execute -m orchestration.definitions -j transform_job
