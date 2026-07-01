#!/usr/bin/env bash
set -euo pipefail

JOBMANAGER_HOST="${FLINK_JOBMANAGER:-localhost}"
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
MINIO_HOST="${MINIO_HOST:-minio}"
MINIO_PORT="${MINIO_PORT:-9000}"
MAX_WAIT="${MAX_WAIT_SECONDS:-300}"

wait_for() {
    local name="$1"
    local cmd="$2"
    local elapsed=0

    echo "Waiting for ${name}..."
    until eval "${cmd}"; do
        sleep 2
        elapsed=$((elapsed + 2))
        if [ "${elapsed}" -ge "${MAX_WAIT}" ]; then
            echo "Timed out waiting for ${name}" >&2
            exit 1
        fi
    done
    echo "${name} is ready"
}

wait_for "Flink JobManager" "curl -sf http://${JOBMANAGER_HOST}:8081/overview >/dev/null"
wait_for "Flink TaskManager" "curl -sf http://${JOBMANAGER_HOST}:8081/overview | grep -qE '\"taskmanagers\":[1-9]'"
wait_for "PostgreSQL" "bash -c '</dev/tcp/${POSTGRES_HOST}/${POSTGRES_PORT}'"
wait_for "MinIO" "curl -sf http://${MINIO_HOST}:${MINIO_PORT}/minio/health/live >/dev/null"

echo "Submitting Flink SQL pipeline (Postgres + MinIO dual sink)..."
exec /opt/flink/bin/sql-client.sh \
    -D execution.detached=true \
    -f /opt/flink/sql/pipeline.sql
