-- Demo seed: 7 days of hourly multi-source history so mart_daily_prices and
-- trend charts have real depth for screenshots. Idempotent (ON CONFLICT DO NOTHING).
-- NOT for CI (ci/seed_raw.sql) and not needed in normal operation.
--
-- IMPORTANT: silver.crypto_prices_clean is incremental and skips rows older than
-- its current max(recorded_at). After seeding, run a full refresh:
--   docker compose run --rm transform bash -c \
--     "dbt deps --profiles-dir /app/dbt && dbt run --full-refresh --profiles-dir /app/dbt"
-- (scripts/seed_demo_history.sh does both steps.)

WITH ticks AS (
    SELECT
        gs AS recorded_at,
        extract(epoch FROM gs) AS ep
    FROM generate_series(
        NOW() - INTERVAL '7 days',
        NOW() - INTERVAL '2 hours',
        INTERVAL '1 hour'
    ) AS gs
),
coins(coin_id, symbol, base_price, base_market_cap) AS (
    VALUES
        ('bitcoin',  'btc', 60000.0::numeric, 1200000000000.0::numeric),
        ('ethereum', 'eth',  1600.0::numeric,  200000000000.0::numeric),
        ('solana',   'sol',    75.0::numeric,   35000000000.0::numeric)
),
sources(source, source_offset) AS (
    -- Small constant offset on Binance keeps spread_pct visibly non-zero
    VALUES ('coingecko', 0.0), ('binance', 0.0012)
),
priced AS (
    SELECT
        c.coin_id,
        s.source,
        c.symbol,
        t.recorded_at,
        -- Multi-day swing (~±5%) + intraday wobble (~±1%) + per-source offset
        (1
            + 0.05 * sin(t.ep / 86400.0 * 1.8 + length(c.coin_id))
            + 0.01 * sin(t.ep / 3600.0 * 0.7 + length(c.coin_id) * 2)
            + s.source_offset
        ) AS price_factor,
        c.base_price,
        c.base_market_cap
    FROM ticks t
    CROSS JOIN coins c
    CROSS JOIN sources s
)
INSERT INTO raw.crypto_prices
    (coin_id, source, symbol, price_usd, market_cap, change_24h, recorded_at)
SELECT
    coin_id,
    source,
    symbol,
    round((base_price * price_factor)::numeric, 8),
    CASE WHEN source = 'coingecko'
         THEN round((base_market_cap * price_factor)::numeric, 2)
    END,
    CASE WHEN source = 'coingecko'
         THEN round(((price_factor - 1) * 100)::numeric, 4)
    END,
    recorded_at
FROM priced
ON CONFLICT (coin_id, source, recorded_at) DO NOTHING;
