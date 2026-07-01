-- Null and sanity checks on gold marts
SELECT 'mart_latest_prices' AS mart,
       count(*) AS total_rows,
       count(*) FILTER (WHERE price_usd IS NULL) AS null_prices,
       count(*) FILTER (WHERE price_usd <= 0) AS non_positive_prices
FROM gold.mart_latest_prices
UNION ALL
SELECT 'mart_source_price_comparison',
       count(*),
       count(*) FILTER (WHERE coingecko_price_usd IS NULL OR binance_price_usd IS NULL),
       count(*) FILTER (WHERE coingecko_price_usd <= 0 OR binance_price_usd <= 0)
FROM gold.mart_source_price_comparison;
