{{
    config(
        tags=['gold']
    )
}}

select
    coin_id,
    source,
    symbol,
    price_usd,
    market_cap,
    change_24h,
    last_recorded_at
from (
    select
        coin_id,
        source,
        symbol,
        price_usd,
        market_cap,
        change_24h,
        recorded_at as last_recorded_at,
        row_number() over (
            partition by coin_id, source
            order by recorded_at desc
        ) as rn
    from {{ ref('crypto_prices_clean') }}
) latest
where rn = 1
