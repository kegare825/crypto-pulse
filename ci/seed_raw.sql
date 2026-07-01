-- CI seed: recent multi-source ticks for dbt run/test (do not use in production)
INSERT INTO raw.crypto_prices (coin_id, source, symbol, price_usd, market_cap, change_24h, recorded_at)
VALUES
    ('bitcoin', 'coingecko', 'btc', 60000.00, 1200000000000.00, 1.5, NOW() - INTERVAL '2 minutes'),
    ('ethereum', 'coingecko', 'eth', 1600.00, 200000000000.00, -0.3, NOW() - INTERVAL '2 minutes'),
    ('solana', 'coingecko', 'sol', 75.00, 35000000000.00, 2.1, NOW() - INTERVAL '2 minutes'),
    ('bitcoin', 'binance', 'btc', 60100.00, NULL, NULL, NOW() - INTERVAL '1 minute'),
    ('ethereum', 'binance', 'eth', 1605.00, NULL, NULL, NOW() - INTERVAL '1 minute'),
    ('solana', 'binance', 'sol', 75.10, NULL, NULL, NOW() - INTERVAL '1 minute'),
    ('bitcoin', 'coingecko', 'btc', 59950.00, 1190000000000.00, 1.2, NOW() - INTERVAL '1 hour'),
    ('bitcoin', 'binance', 'btc', 60050.00, NULL, NULL, NOW() - INTERVAL '1 hour')
ON CONFLICT (coin_id, source, recorded_at) DO NOTHING;
