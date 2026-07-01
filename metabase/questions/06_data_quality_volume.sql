-- Row counts across pipeline zones (last 24h where applicable)
SELECT 'raw' AS zone, source, count(*) AS row_count
FROM raw.crypto_prices
WHERE recorded_at >= NOW() - INTERVAL '24 hours'
GROUP BY source
UNION ALL
SELECT 'silver' AS zone, source, count(*) AS row_count
FROM silver.crypto_prices_clean
WHERE recorded_at >= NOW() - INTERVAL '24 hours'
GROUP BY source
UNION ALL
SELECT 'gold_latest_by_source' AS zone, source, count(*) AS row_count
FROM gold.mart_latest_prices_by_source
GROUP BY source
ORDER BY zone, source;
