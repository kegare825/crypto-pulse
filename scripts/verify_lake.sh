#!/usr/bin/env bash
# List recent Parquet objects in the MinIO raw lake path.
set -euo pipefail

MINIO_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin}"
MINIO_BUCKET="${MINIO_BUCKET:-crypto-pulse}"
LAKE_PREFIX="${LAKE_RAW_PREFIX:-raw/crypto_prices}"
NETWORK="${COMPOSE_PROJECT_NAME:-crypto-pulse}_default"

if ! docker network inspect "${NETWORK}" >/dev/null 2>&1; then
    echo "Network ${NETWORK} not found. Start the stack first: docker compose up -d" >&2
    exit 1
fi

echo "=== MinIO lake: s3://${MINIO_BUCKET}/${LAKE_PREFIX}/ ==="
docker run --rm --network "${NETWORK}" minio/mc:RELEASE.2025-08-13T08-35-41Z \
    sh -c "
        mc alias set cp http://minio:9000 '${MINIO_USER}' '${MINIO_PASSWORD}' &&
        mc ls -r cp/${MINIO_BUCKET}/${LAKE_PREFIX}/ 2>/dev/null | tail -30 ||
        echo '(no objects yet — wait for Flink job + ingest traffic)'
    "

echo ""
echo "Console: http://localhost:9001 (user: ${MINIO_USER})"
