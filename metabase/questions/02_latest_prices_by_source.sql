SELECT
    coin_id,
    source,
    symbol,
    price_usd,
    change_24h,
    last_recorded_at
FROM gold.mart_latest_prices_by_source
ORDER BY coin_id, source;
