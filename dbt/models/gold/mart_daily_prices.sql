{{
    config(
        tags=['gold']
    )
}}

select
    coin_id,
    source,
    date_trunc('day', recorded_at)::date as price_date,
    round(avg(price_usd), 8) as avg_price_usd,
    max(price_usd) as max_price_usd,
    min(price_usd) as min_price_usd,
    count(*) as sample_count
from {{ ref('crypto_prices_clean') }}
group by 1, 2, 3
