{{
    config(
        tags=['gold']
    )
}}

select
    'mart_latest_prices' as mart,
    count(*) as total_rows,
    count(*) filter (where price_usd is null) as null_prices,
    count(*) filter (where price_usd <= 0) as non_positive_prices
from {{ ref('mart_latest_prices') }}

union all

select
    'mart_source_price_comparison',
    count(*),
    count(*) filter (where coingecko_price_usd is null or binance_price_usd is null),
    count(*) filter (where coingecko_price_usd <= 0 or binance_price_usd <= 0)
from {{ ref('mart_source_price_comparison') }}
