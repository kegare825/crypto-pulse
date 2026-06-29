#!/usr/bin/env bash
set -euo pipefail

INTERVAL="${TRANSFORM_INTERVAL_SECONDS:-300}"
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
MAX_WAIT="${MAX_WAIT_SECONDS:-120}"

wait_for_postgres() {
    local elapsed=0
    until bash -c "echo > /dev/tcp/${POSTGRES_HOST}/${POSTGRES_PORT}"; do
        sleep 2
        elapsed=$((elapsed + 2))
        if [ "${elapsed}" -ge "${MAX_WAIT}" ]; then
            echo "Timed out waiting for PostgreSQL" >&2
            exit 1
        fi
    done
}

run_cycle() {
    echo "========================================"
    echo "Transform cycle at $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "========================================"

    echo "--- dbt deps ---"
    dbt deps --profiles-dir /app/dbt

    echo "--- dbt run ---"
    dbt run --profiles-dir /app/dbt

    echo "--- dbt test ---"
    if ! dbt test --profiles-dir /app/dbt; then
        echo "[WARN] dbt tests failed"
    fi

    echo "--- Great Expectations ---"
    if ! python /app/validate.py; then
        echo "[WARN] Great Expectations validation failed"
    fi

    echo "Cycle complete. Next run in ${INTERVAL}s"
}

wait_for_postgres
echo "PostgreSQL ready. Starting transform loop (interval=${INTERVAL}s)"

while true; do
    run_cycle || echo "[WARN] transform cycle encountered errors"
    sleep "${INTERVAL}"
done
