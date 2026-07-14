#!/usr/bin/env bash
# Seed 7 days of hourly demo history and rebuild dbt models (full refresh),
# so mart_daily_prices and Metabase trend charts have depth for screenshots.
#
# Usage (stack running): bash scripts/seed_demo_history.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="${POSTGRES_DOCKER_CONTAINER:-crypto-pulse-postgres}"
PGUSER="${POSTGRES_USER:-pulse}"
PGDATABASE="${POSTGRES_DB:-cryptopulse}"

echo "=== Seeding 7 days of hourly history into raw.crypto_prices ==="
docker exec -i "${CONTAINER}" psql -U "${PGUSER}" -d "${PGDATABASE}" \
    < "${ROOT}/scripts/seed_demo_history.sql"

echo "=== Rebuilding silver + gold (full refresh, incremental model must re-read history) ==="
docker compose -f "${ROOT}/docker-compose.yml" run --rm transform bash -c \
    "dbt deps --profiles-dir /app/dbt && dbt run --full-refresh --profiles-dir /app/dbt"

echo "=== Done. Check gold.mart_daily_prices ==="
docker exec "${CONTAINER}" psql -U "${PGUSER}" -d "${PGDATABASE}" -c \
    "SELECT coin_id, source, price_date, avg_price_usd, sample_count
     FROM gold.mart_daily_prices ORDER BY price_date DESC, coin_id, source LIMIT 12;"
