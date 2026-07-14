# ADR 007: Dead-letter queue for invalid payloads

## Status

Accepted

## Context

Both Kafka source tables in `flink/sql/pipeline.sql` are declared with `'json.ignore-parse-errors' = 'true'` and `'json.fail-on-missing-field' = 'false'`. This is deliberate — a single malformed message must not crash the streaming job — but the side effect was that invalid or incomplete payloads were **silently dropped**: the row deserializes to nulls, fails the `WHERE ... IS NOT NULL` guard in `unified_prices`, and disappears with no trace. This was called out as a known limitation in `docs/ARCHITECTURE.md`.

Producers already validate against the shared contract before publishing (ADR 003), so in normal operation this path should rarely trigger. It exists as a safety net for schema drift, manual topic writes, replay of old formats, or a future producer that skips validation.

## Decision

Add a **dead-letter topic** (`crypto-pulse.dlq`, default name, configurable via `KAFKA_DLQ_TOPIC`) fed directly from Flink SQL:

- A second consumer group per source topic (`flink-crypto-pulse-*-dlq`) reads the same topics using `'format' = 'raw'` — i.e. as an opaque `STRING`, bypassing JSON deserialization entirely so nothing is lost before inspection.
- `JSON_VALUE` + `TRY_CAST(... AS DOUBLE)` checks (coin_id, price_usd, event_time) classify each row; anything that fails is written to `kafka_dlq` with the original raw string, a `reason`, and the Kafka record timestamp. Do **not** use `JSON_VALUE(... RETURNING DOUBLE NULL ON ERROR)` here — see [postmortem 2026-07-13](../incidents/2026-07-13-flink-dlq-classcastexception.md).
- Both DLQ inserts run inside the same `EXECUTE STATEMENT SET` as the existing dual-sink inserts, so it stays **one Flink job** (keeps `flink-watchdog`'s "no running jobs" check meaningful).
- A small dedicated service, `dlq-monitor` (mirrors `ingest/`/`binance-ingest/` shape), consumes `crypto-pulse.dlq`, logs each rejected payload, and exposes `crypto_pulse_dlq_messages_total{source_topic,reason}` on `:8002/metrics`.
- Prometheus alert `DeadLetterMessagesDetected` fires on any dead-lettered message sustained for 5 minutes.

## Alternatives considered

| Option | Why not (for now) |
|--------|--------------------|
| Fail the job on any bad record | Defeats the purpose of a streaming pipeline — one bad message would take down ingest for all sources |
| Filter silently (status quo) | No visibility into data loss; can't debug a producer regression or schema drift |
| Kafka Connect / ksqlDB dead-letter sink | Extra infra just for this; Flink SQL can express the same split declaratively with functions already in scope |
| Validate only in Python producers, skip Flink-side DLQ | Doesn't catch messages written by something other than the two known producers (replay, manual test writes, future producers) |

## Consequences

**Pros:** No more silent data loss; a concrete signal (metric + alert + logs) for "something is producing bad data"; closes a documented known limitation without adding new infrastructure (same Kafka cluster, same Flink job).

**Cons:** Two extra Kafka consumer groups per source topic (raw-format readers) add modest overhead; the DLQ classification is intentionally coarse (three checks) — enough to flag a problem, not a full second contract validator. Reprocessing/replay from the DLQ is manual today (`docker compose logs -f dlq-monitor` or read the topic directly) — no auto-retry.
