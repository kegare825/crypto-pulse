#!/usr/bin/env bash
# Smoke test: Postgres + dbt + GX + gold marts (no Kafka/Flink).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

export POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
export POSTGRES_PORT="${POSTGRES_PORT:-5432}"
export POSTGRES_USER="${POSTGRES_USER:-pulse}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-pulse}"
export POSTGRES_DB="${POSTGRES_DB:-cryptopulse}"

echo "=== Smoke: init Postgres + seed ==="
bash ci/init_postgres.sh

echo "=== Smoke: dbt run + test ==="
(
    cd dbt
    dbt deps --profiles-dir .
    dbt run --profiles-dir .
    dbt test --profiles-dir .
)

echo "=== Smoke: Great Expectations ==="
python quality/validate.py

echo "=== Smoke: gold mart row counts ==="
check_sql() {
    local label="$1"
    local sql="$2"
    local count
    count=$(PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" \
        -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -tAc "${sql}")
    if [ "${count}" -lt 1 ]; then
        echo "FAIL: ${label} returned ${count} rows" >&2
        exit 1
    fi
    echo "OK: ${label} (${count} rows)"
}

if command -v psql >/dev/null 2>&1; then
    check_sql "mart_latest_prices" "SELECT count(*) FROM gold.mart_latest_prices"
    check_sql "mart_source_price_comparison" "SELECT count(*) FROM gold.mart_source_price_comparison"
    check_sql "mart_freshness_by_source" "SELECT count(*) FROM gold.mart_freshness_by_source"
    check_sql "mart_zone_volume" "SELECT count(*) FROM gold.mart_zone_volume"
else
    docker exec crypto-pulse-postgres psql -U pulse -d cryptopulse -tAc \
        "SELECT count(*) FROM gold.mart_latest_prices" | grep -qv '^0$'
    echo "OK: gold marts via docker exec (psql not on host)"
fi

echo "=== Smoke test passed ==="
