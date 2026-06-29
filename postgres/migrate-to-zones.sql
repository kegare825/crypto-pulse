-- Run once when upgrading from public.crypto_prices to zone architecture:
-- docker exec -i crypto-pulse-postgres psql -U pulse -d cryptopulse < postgres/migrate-to-zones.sql

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

CREATE TABLE IF NOT EXISTS raw.crypto_prices (
    coin_id     TEXT        NOT NULL,
    symbol      TEXT,
    price_usd   NUMERIC(20, 8),
    market_cap  NUMERIC(30, 2),
    change_24h  NUMERIC(10, 4),
    recorded_at TIMESTAMPTZ NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (coin_id, recorded_at)
);

INSERT INTO raw.crypto_prices (coin_id, symbol, price_usd, market_cap, change_24h, recorded_at)
SELECT coin_id, symbol, price_usd, market_cap, change_24h, recorded_at
FROM public.crypto_prices
ON CONFLICT (coin_id, recorded_at) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_raw_crypto_prices_recorded_at
    ON raw.crypto_prices (recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_raw_crypto_prices_coin_id
    ON raw.crypto_prices (coin_id, recorded_at DESC);
