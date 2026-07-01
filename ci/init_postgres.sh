#!/usr/bin/env bash
# Apply zone DDL and CI seed data to Postgres (GitHub Actions + local via Docker).
set -euo pipefail

PGHOST="${POSTGRES_HOST:-localhost}"
PGPORT="${POSTGRES_PORT:-5432}"
PGUSER="${POSTGRES_USER:-pulse}"
PGPASSWORD="${POSTGRES_PASSWORD:-pulse}"
PGDATABASE="${POSTGRES_DB:-cryptopulse}"
DOCKER_CONTAINER="${POSTGRES_DOCKER_CONTAINER:-crypto-pulse-postgres}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export PGPASSWORD

wait_for_postgres() {
    if command -v pg_isready >/dev/null 2>&1; then
        until pg_isready -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}"; do
            sleep 1
        done
        return
    fi

    if docker ps --format '{{.Names}}' | grep -qx "${DOCKER_CONTAINER}"; then
        until docker exec "${DOCKER_CONTAINER}" pg_isready -U "${PGUSER}" -d "${PGDATABASE}"; do
            sleep 1
        done
        return
    fi

    until bash -c "echo > /dev/tcp/${PGHOST}/${PGPORT}" 2>/dev/null; do
        sleep 1
    done
}

run_psql_file() {
    local file="$1"
    if command -v psql >/dev/null 2>&1; then
        psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -f "${file}"
    elif docker ps --format '{{.Names}}' | grep -qx "${DOCKER_CONTAINER}"; then
        docker exec -i "${DOCKER_CONTAINER}" psql -U "${PGUSER}" -d "${PGDATABASE}" < "${file}"
    else
        echo "Need psql client or running container ${DOCKER_CONTAINER}" >&2
        exit 1
    fi
}

wait_for_postgres
run_psql_file "${ROOT}/postgres/init/001_zones.sql"
run_psql_file "${ROOT}/ci/seed_raw.sql"

echo "Postgres ready with zones + seed data"
