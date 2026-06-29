-- Add source column and widen primary key for multi-source raw data.
-- docker exec -i crypto-pulse-postgres psql -U pulse -d cryptopulse < postgres/migrate-add-source.sql

ALTER TABLE raw.crypto_prices
    ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'coingecko';

UPDATE raw.crypto_prices SET source = 'coingecko' WHERE source IS NULL;

ALTER TABLE raw.crypto_prices DROP CONSTRAINT IF EXISTS crypto_prices_pkey;

ALTER TABLE raw.crypto_prices
    ADD CONSTRAINT crypto_prices_pkey PRIMARY KEY (coin_id, source, recorded_at);

CREATE INDEX IF NOT EXISTS idx_raw_crypto_prices_source
    ON raw.crypto_prices (source, recorded_at DESC);
