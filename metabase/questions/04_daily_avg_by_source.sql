SELECT
    price_date,
    coin_id,
    source,
    avg_price_usd
FROM gold.mart_daily_prices
ORDER BY price_date, coin_id, source;
