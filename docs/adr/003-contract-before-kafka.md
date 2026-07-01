# ADR 003: JSON Schema validation before Kafka

## Status

Accepted

## Context

Downstream (Flink, dbt, GX, Metabase) assumes a stable event shape. Bad payloads in Kafka are expensive to detect and Flink is configured to ignore parse errors silently.

## Decision

Validate every normalized event against `contracts/crypto_price_event.schema.json` **in the ingest process** before `producer.produce()`. Mirror the same rules in CI via pytest.

## Alternatives considered

| Option | Why not |
|--------|---------|
| Validate only in CI | Runtime drift from tests; broken events still land in Kafka |
| Validate only in Flink | Too late — Kafka retention and lake files already polluted |
| Avro + Schema Registry | Heavier ops for a portfolio; JSON + JSON Schema is enough to show contract-first design |

## Consequences

**Pros:** Fail fast at the edge; single contract for CoinGecko and Binance; shift-left quality.

**Cons:** Schema evolution must be coordinated; tiny latency add on publish (negligible at this volume).
