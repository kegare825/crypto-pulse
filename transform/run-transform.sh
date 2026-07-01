#!/usr/bin/env bash
# One-off transform cycle (same assets as Dagster schedule). Prefer Dagster UI on :3002.
set -euo pipefail

export DAGSTER_HOME="${DAGSTER_HOME:-/tmp/dagster}"
export PYTHONPATH="${PYTHONPATH:-/app}"
mkdir -p "${DAGSTER_HOME}"

dagster job execute -m orchestration.definitions -j transform_job
