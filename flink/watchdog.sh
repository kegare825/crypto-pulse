#!/usr/bin/env bash
# Resubmit the Flink SQL pipeline if no job is running (self-heal after JM/TM restarts).
set -euo pipefail

JOBMANAGER_HOST="${FLINK_JOBMANAGER:-flink-jobmanager}"
JOBMANAGER_PORT="${FLINK_JOBMANAGER_PORT:-8081}"
CHECK_INTERVAL="${FLINK_WATCHDOG_INTERVAL_SECONDS:-60}"
PIPELINE_SQL="${FLINK_PIPELINE_SQL:-/opt/flink/sql/pipeline.sql}"
MAX_WAIT="${MAX_WAIT_SECONDS:-300}"

wait_for_flink() {
    local elapsed=0
    until curl -sf "http://${JOBMANAGER_HOST}:${JOBMANAGER_PORT}/overview" >/dev/null; do
        sleep 2
        elapsed=$((elapsed + 2))
        if [ "${elapsed}" -ge "${MAX_WAIT}" ]; then
            echo "Timed out waiting for Flink JobManager" >&2
            exit 1
        fi
    done
}

count_active_jobs() {
    curl -sf "http://${JOBMANAGER_HOST}:${JOBMANAGER_PORT}/jobs/overview" \
        | { grep -oE '"state":"(RUNNING|CREATED|RESTARTING|INITIALIZING)"' || true; } \
        | wc -l
}

submit_pipeline() {
    echo "Watchdog: submitting pipeline from ${PIPELINE_SQL}"
    /opt/flink/bin/sql-client.sh \
        -D execution.detached=true \
        -f "${PIPELINE_SQL}"
}

wait_for_flink
echo "Flink watchdog active (interval=${CHECK_INTERVAL}s)"

while true; do
    active="$(count_active_jobs | tr -d ' ')"
    if [ "${active}" -eq 0 ]; then
        echo "Watchdog: no active Flink jobs detected"
        if submit_pipeline; then
            echo "Watchdog: pipeline submitted"
        else
            echo "Watchdog: pipeline submit failed, will retry" >&2
        fi
    fi
    sleep "${CHECK_INTERVAL}"
done
