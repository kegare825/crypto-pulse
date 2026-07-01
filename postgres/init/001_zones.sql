-- Data zones: raw (landing) | silver (cleaned) | gold (BI marts)
-- silver and gold tables are managed by dbt

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

CREATE TABLE IF NOT EXISTS raw.crypto_prices (
    coin_id     TEXT        NOT NULL,
    source      TEXT        NOT NULL DEFAULT 'coingecko',
    symbol      TEXT,
    price_usd   NUMERIC(20, 8),
    market_cap  NUMERIC(30, 2),
    change_24h  NUMERIC(10, 4),
    recorded_at TIMESTAMPTZ NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (coin_id, source, recorded_at)
);

CREATE INDEX IF NOT EXISTS idx_raw_crypto_prices_recorded_at
    ON raw.crypto_prices (recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_raw_crypto_prices_coin_id
    ON raw.crypto_prices (coin_id, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_raw_crypto_prices_source
    ON raw.crypto_prices (source, recorded_at DESC);

-- Legacy public table migration (existing deployments)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'crypto_prices'
    ) THEN
        INSERT INTO raw.crypto_prices (coin_id, source, symbol, price_usd, market_cap, change_24h, recorded_at)
        SELECT coin_id, 'coingecko', symbol, price_usd, market_cap, change_24h, recorded_at
        FROM public.crypto_prices
        ON CONFLICT (coin_id, source, recorded_at) DO NOTHING;
    END IF;
END $$;
