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
    recorded_at,
    lag(price_usd) over (
        partition by coin_id, source
        order by recorded_at
    ) as prev_price_usd,
    price_usd - lag(price_usd) over (
        partition by coin_id, source
        order by recorded_at
    ) as price_change_usd,
    case
        when lag(price_usd) over (partition by coin_id, source order by recorded_at) > 0
        then round(
            100.0 * (price_usd - lag(price_usd) over (partition by coin_id, source order by recorded_at))
            / lag(price_usd) over (partition by coin_id, source order by recorded_at),
            4
        )
    end as price_change_pct
from {{ ref('crypto_prices_clean') }}
