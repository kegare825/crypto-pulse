SET 'execution.checkpointing.interval' = '30s';
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
    'scan.startup.mode' = 'earliest-offset',
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
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'json',
    'json.fail-on-missing-field' = 'false',
    'json.ignore-parse-errors' = 'true'
);

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
    'sink.buffer-flush.interval' = '5s'
);

INSERT INTO postgres_prices
SELECT
    coin_id,
    COALESCE(`source`, 'coingecko') AS `source`,
    symbol,
    price_usd,
    market_cap,
    change_24h,
    event_ts AS recorded_at
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
    event_ts AS recorded_at
FROM kafka_binance_trades
WHERE event_ts IS NOT NULL
  AND coin_id IS NOT NULL
  AND price_usd IS NOT NULL;
