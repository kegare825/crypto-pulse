# ADR 006: Kafka and Flink fault tolerance (portfolio scope)

## Status

Accepted

## Context

Single-node Docker Compose cannot provide true HA, but ingest and streaming should survive transient broker restarts, producer blips, and Flink TaskManager/JobManager recoveries without manual intervention.

## Decision

**Kafka**

- Persistent volume for broker log data (`kafka_data`)
- `restart: unless-stopped` on broker
- Explicit topic creation via `kafka-init` (retention, partitions); disable auto-create
- Producers use idempotent `acks=all` with retries (`contracts/kafka_producer.py`)

**Flink**

- Checkpointing (EXACTLY_ONCE, 30s) to shared volume `flink_checkpoints`
- Fixed-delay restart strategy (10 attempts, 15s delay)
- Kafka sources: `read_committed`, consumer reconnect/backoff, offset restore via checkpoints
- JDBC sink: connection retry + max retries
- `flink-watchdog` service resubmits SQL job if no active job detected
- Initial one-shot `flink-submitter`; ongoing healing via watchdog

## Alternatives considered

| Option | Why not (for now) |
|--------|-------------------|
| Multi-broker Kafka cluster | Operational cost; out of portfolio scope |
| Flink HA (multiple JMs) | Requires ZooKeeper/K8s or complex compose |
| Always-on submitter loop only | Does not heal mid-run failures; watchdog + restart strategy is clearer |

## Consequences

**Pros:** Better demo stability; offsets and state survive restarts; documents production direction.

**Cons:** Still single broker; watchdog may resubmit duplicate job names if API race — acceptable at this scale; not a substitute for managed Flink/Kafka.
