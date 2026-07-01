-- Per-coin freshness gap between sources (comparison SLA)
SELECT
    coin_id,
    coingecko_at,
    binance_at,
    round(
        extract(epoch FROM (coingecko_at - binance_at)) / 60.0,
        1
    ) AS coingecko_minus_binance_minutes
FROM gold.mart_source_price_comparison
ORDER BY coin_id;
