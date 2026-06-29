SELECT
    coin_id,
    symbol,
    spread_pct,
    spread_usd
FROM gold.mart_source_price_comparison
ORDER BY spread_pct DESC NULLS LAST;
