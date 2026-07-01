# ADR 001: Separate Kafka topics per source

## Status

Accepted

## Context

CoinGecko (REST poll, ~60s) and Binance (WebSocket trades, high frequency) feed the same downstream pipeline but have different semantics, throughput, and failure modes.

## Decision

Use two topics: `coingecko.prices.raw` and `binance.trades.raw`. Flink reads both with **separate consumer groups** and merges via `UNION ALL`.

## Alternatives considered

| Option | Why not |
|--------|---------|
| Single topic `crypto.prices.raw` | Mixed retention, harder debugging, one consumer group for heterogeneous sources |
| Direct JDBC ingest (skip Kafka) | Loses replay, decoupling, and streaming story for the portfolio |

## Consequences

**Pros:** Clear ownership per source; independent lag monitoring; easier to add a third source later.

**Cons:** Two topics to operate; Flink SQL must union sources explicitly (a comma-separated topic list does not work as expected in Flink Kafka connector).
