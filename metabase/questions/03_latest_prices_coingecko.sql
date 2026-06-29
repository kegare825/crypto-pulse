SELECT
    coin_id,
    symbol,
    price_usd,
    market_cap,
    change_24h,
    last_recorded_at
FROM gold.mart_latest_prices
ORDER BY coin_id;
