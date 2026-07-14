SET 'execution.checkpointing.interval' = '30s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.externalized-checkpoint-retention' = 'RETAIN_ON_CANCELLATION';
SET 'execution.checkpointing.timeout' = '5 min';
SET 'state.backend' = 'hashmap';
SET 'state.checkpoints.dir' = 'file:///tmp/flink-checkpoints';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '10';
SET 'restart-strategy.fixed-delay.delay' = '15s';
SET 'parallelism.default' = '1';
SET 'execution.detached' = 'true';

CREATE TABLE kafka_coingecko_prices (
    coin_id     STRING,
    symbol      STRING,
    price_usd   DOUBLE,
    market_cap  DOUBLE,
    change_24h  DOUBLE,
    event_time  STRING,
    `source`    STRING,
    event_ts AS TO_TIMESTAMP(
        REGEXP_REPLACE(event_time, '([+-][0-9]{2}:[0-9]{2})$', ''),
        'yyyy-MM-dd''T''HH:mm:ss.SSSSSS'
    ),
    WATERMARK FOR event_ts AS event_ts - INTERVAL '15' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'coingecko.prices.raw',
    'properties.bootstrap.servers' = 'kafka:9093',
    'properties.group.id' = 'flink-crypto-pulse-coingecko',
    'scan.startup.mode' = 'group-offsets',
    'properties.auto.offset.reset' = 'earliest',
    'properties.isolation.level' = 'read_committed',
    'properties.enable.auto.commit' = 'false',
    'properties.session.timeout.ms' = '45000',
    'properties.request.timeout.ms' = '60000',
    'properties.retry.backoff.ms' = '1000',
    'properties.reconnect.backoff.max.ms' = '10000',
    'format' = 'json',
    'json.fail-on-missing-field' = 'false',
    'json.ignore-parse-errors' = 'true'
);

CREATE TABLE kafka_binance_trades (
    coin_id     STRING,
    symbol      STRING,
    price_usd   DOUBLE,
    market_cap  DOUBLE,
    change_24h  DOUBLE,
    event_time  STRING,
    `source`    STRING,
    event_ts AS TO_TIMESTAMP(
        REGEXP_REPLACE(event_time, '([+-][0-9]{2}:[0-9]{2})$', ''),
        'yyyy-MM-dd''T''HH:mm:ss.SSSSSS'
    ),
    WATERMARK FOR event_ts AS event_ts - INTERVAL '15' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'binance.trades.raw',
    'properties.bootstrap.servers' = 'kafka:9093',
    'properties.group.id' = 'flink-crypto-pulse-binance',
    'scan.startup.mode' = 'group-offsets',
    'properties.auto.offset.reset' = 'earliest',
    'properties.isolation.level' = 'read_committed',
    'properties.enable.auto.commit' = 'false',
    'properties.session.timeout.ms' = '45000',
    'properties.request.timeout.ms' = '60000',
    'properties.retry.backoff.ms' = '1000',
    'properties.reconnect.backoff.max.ms' = '10000',
    'format' = 'json',
    'json.fail-on-missing-field' = 'false',
    'json.ignore-parse-errors' = 'true'
);

-- Serving layer: operational raw cache in PostgreSQL (dbt reads this today)
CREATE TABLE postgres_prices (
    coin_id     STRING,
    `source`    STRING,
    symbol      STRING,
    price_usd   DOUBLE,
    market_cap  DOUBLE,
    change_24h  DOUBLE,
    recorded_at TIMESTAMP(3),
    PRIMARY KEY (coin_id, source, recorded_at) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://postgres:5432/cryptopulse',
    'table-name' = 'raw.crypto_prices',
    'username' = 'pulse',
    'password' = 'pulse',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '50',
    'sink.buffer-flush.interval' = '5s',
    'connection.max-retry-timeout' = '60s',
    'sink.max-retries' = '5'
);

-- Storage layer: immutable Parquet on MinIO (S3-compatible), Hive-style partitions
CREATE TABLE lake_crypto_prices (
    symbol      STRING,
    price_usd   DOUBLE,
    market_cap  DOUBLE,
    change_24h  DOUBLE,
    recorded_at TIMESTAMP(3),
    `source`    STRING,
    coin_id     STRING,
    dt          STRING
) PARTITIONED BY (`source`, coin_id, dt)
WITH (
    'connector' = 'filesystem',
    'path' = 's3a://crypto-pulse/raw/crypto_prices',
    'format' = 'parquet',
    'parquet.compression' = 'snappy',
    'sink.partition-commit.policy.kind' = 'success-file',
    'sink.partition-commit.delay' = '1 min',
    'sink.rolling-policy.rollover-interval' = '5 min'
);

-- Dead-letter queue: a second, independently-grouped consumer reads each raw
-- topic as an opaque STRING (format=raw) so malformed/incomplete payloads
-- can be inspected instead of silently vanishing behind
-- 'json.ignore-parse-errors' = 'true' above. See ADR 007.
CREATE TABLE kafka_coingecko_raw (
    raw_value STRING,
    kafka_ts  TIMESTAMP_LTZ(3) METADATA FROM 'timestamp' VIRTUAL
) WITH (
    'connector' = 'kafka',
    'topic' = 'coingecko.prices.raw',
    'properties.bootstrap.servers' = 'kafka:9093',
    'properties.group.id' = 'flink-crypto-pulse-coingecko-dlq',
    'scan.startup.mode' = 'group-offsets',
    'properties.auto.offset.reset' = 'earliest',
    'format' = 'raw'
);

CREATE TABLE kafka_binance_raw (
    raw_value STRING,
    kafka_ts  TIMESTAMP_LTZ(3) METADATA FROM 'timestamp' VIRTUAL
) WITH (
    'connector' = 'kafka',
    'topic' = 'binance.trades.raw',
    'properties.bootstrap.servers' = 'kafka:9093',
    'properties.group.id' = 'flink-crypto-pulse-binance-dlq',
    'scan.startup.mode' = 'group-offsets',
    'properties.auto.offset.reset' = 'earliest',
    'format' = 'raw'
);

CREATE TABLE kafka_dlq (
    source_topic STRING,
    raw_value    STRING,
    reason       STRING,
    failed_at    TIMESTAMP_LTZ(3)
) WITH (
    'connector' = 'kafka',
    'topic' = 'crypto-pulse.dlq',
    'properties.bootstrap.servers' = 'kafka:9093',
    'format' = 'json'
);

-- Note: JSON_VALUE(... RETURNING DOUBLE NULL ON ERROR) is unsafe here — Calcite's
-- runtime cast can throw ClassCastException (Integer -> Double) *after* JSON_VALUE
-- already returned successfully, bypassing NULL ON ERROR and crashing the job.
-- Extracting as STRING (the default) and using TRY_CAST sidesteps that entirely.
CREATE TEMPORARY VIEW coingecko_validation AS
SELECT
    raw_value,
    kafka_ts,
    CASE
        WHEN JSON_VALUE(raw_value, '$.coin_id' NULL ON ERROR) IS NULL
            THEN 'invalid_json_or_missing_coin_id'
        WHEN TRY_CAST(JSON_VALUE(raw_value, '$.price_usd' NULL ON ERROR) AS DOUBLE) IS NULL
            THEN 'missing_or_invalid_price_usd'
        WHEN JSON_VALUE(raw_value, '$.event_time' NULL ON ERROR) IS NULL
            THEN 'missing_event_time'
        ELSE CAST(NULL AS STRING)
    END AS reason
FROM kafka_coingecko_raw;

CREATE TEMPORARY VIEW binance_validation AS
SELECT
    raw_value,
    kafka_ts,
    CASE
        WHEN JSON_VALUE(raw_value, '$.coin_id' NULL ON ERROR) IS NULL
            THEN 'invalid_json_or_missing_coin_id'
        WHEN TRY_CAST(JSON_VALUE(raw_value, '$.price_usd' NULL ON ERROR) AS DOUBLE) IS NULL
            THEN 'missing_or_invalid_price_usd'
        WHEN JSON_VALUE(raw_value, '$.event_time' NULL ON ERROR) IS NULL
            THEN 'missing_event_time'
        ELSE CAST(NULL AS STRING)
    END AS reason
FROM kafka_binance_raw;

CREATE TEMPORARY VIEW unified_prices AS
SELECT
    coin_id,
    COALESCE(`source`, 'coingecko') AS `source`,
    symbol,
    price_usd,
    market_cap,
    change_24h,
    event_ts AS recorded_at,
    DATE_FORMAT(event_ts, 'yyyy-MM-dd') AS dt
FROM kafka_coingecko_prices
WHERE event_ts IS NOT NULL
  AND coin_id IS NOT NULL
  AND price_usd IS NOT NULL
UNION ALL
SELECT
    coin_id,
    COALESCE(`source`, 'binance') AS `source`,
    symbol,
    price_usd,
    market_cap,
    change_24h,
    event_ts AS recorded_at,
    DATE_FORMAT(event_ts, 'yyyy-MM-dd') AS dt
FROM kafka_binance_trades
WHERE event_ts IS NOT NULL
  AND coin_id IS NOT NULL
  AND price_usd IS NOT NULL;

EXECUTE STATEMENT SET
BEGIN
    INSERT INTO postgres_prices
    SELECT coin_id, `source`, symbol, price_usd, market_cap, change_24h, recorded_at
    FROM unified_prices;

    INSERT INTO lake_crypto_prices
    SELECT symbol, price_usd, market_cap, change_24h, recorded_at, `source`, coin_id, dt
    FROM unified_prices;

    INSERT INTO kafka_dlq
    SELECT 'coingecko.prices.raw' AS source_topic, raw_value, reason, kafka_ts
    FROM coingecko_validation
    WHERE reason IS NOT NULL
    UNION ALL
    SELECT 'binance.trades.raw' AS source_topic, raw_value, reason, kafka_ts
    FROM binance_validation
    WHERE reason IS NOT NULL;
END;
