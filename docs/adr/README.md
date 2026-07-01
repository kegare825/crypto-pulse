# Architecture Decision Records (ADRs)

Short, durable notes on **why** Crypto Pulse is built this way. Each ADR captures context, the decision, alternatives, and tradeoffs.

| ADR | Title |
|-----|-------|
| [001](001-dual-kafka-topics.md) | Separate Kafka topics per source |
| [002](002-storage-vs-serving.md) | MinIO (storage) + PostgreSQL (serving) |
| [003](003-contract-before-kafka.md) | JSON Schema validation before Kafka |
| [004](004-flink-sql.md) | Flink SQL instead of PyFlink |
| [005](005-iceberg-roadmap.md) | Iceberg on the roadmap (not Hudi/Delta yet) |
| [006](006-resilience-kafka-flink.md) | Kafka persistence + Flink checkpoints and watchdog |

When adding a new ADR, copy the template sections from any existing file and increment the number.
