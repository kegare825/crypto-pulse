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
END;
