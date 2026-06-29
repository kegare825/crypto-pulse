-- CoinGecko vs Binance spread (hero table for portfolio demo)
SELECT
    coin_id,
    symbol,
    coingecko_price_usd,
    binance_price_usd,
    spread_usd,
    spread_pct,
    coingecko_at,
    binance_at
FROM gold.mart_source_price_comparison
ORDER BY coin_id;
