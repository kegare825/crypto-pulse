#!/usr/bin/env bash
# Wait for Postgres, then run Dagster daemon + UI for scheduled transform assets.
set -euo pipefail

POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
MAX_WAIT="${MAX_WAIT_SECONDS:-120}"
DAGSTER_HOME="${DAGSTER_HOME:-/tmp/dagster}"
DAGSTER_PORT="${DAGSTER_PORT:-3002}"

mkdir -p "${DAGSTER_HOME}"

wait_for_postgres() {
    local elapsed=0
    until bash -c "echo > /dev/tcp/${POSTGRES_HOST}/${POSTGRES_PORT}"; do
        sleep 2
        elapsed=$((elapsed + 2))
        if [ "${elapsed}" -ge "${MAX_WAIT}" ]; then
            echo "Timed out waiting for PostgreSQL at ${POSTGRES_HOST}:${POSTGRES_PORT}" >&2
            exit 1
        fi
    done
}

wait_for_postgres
echo "PostgreSQL ready. Preparing dbt manifest for Dagster Software-Defined Assets..."

# @dbt_assets parses dbt/target/manifest.json at import time — it must exist
# before dagster-daemon/dagster-webserver load orchestration.definitions.
(cd /app/dbt && dbt deps --profiles-dir . && dbt parse --profiles-dir .)

echo "Starting Dagster (UI on port ${DAGSTER_PORT})"

mkdir -p "${DAGSTER_HOME}"
touch "${DAGSTER_HOME}/dagster.yaml"
dagster instance migrate

dagster-daemon run -m orchestration.definitions &
DAEMON_PID=$!

# Let daemon finish schedule registration before the webserver and first launch.
sleep 5

# First dbt cycle without waiting for the cron tick; schedule auto-starts via default_status=RUNNING.
(
    sleep 10
    echo "Launching initial transform_job run..."
    dagster job launch -m orchestration.definitions -j transform_job \
        || echo "Initial transform_job launch skipped (daemon may still be starting)" >&2
) &

dagster-webserver -h 0.0.0.0 -p "${DAGSTER_PORT}" -m orchestration.definitions &
WEB_PID=$!

trap 'kill "${DAEMON_PID}" "${WEB_PID}" 2>/dev/null || true' EXIT INT TERM

wait "${DAEMON_PID}"
