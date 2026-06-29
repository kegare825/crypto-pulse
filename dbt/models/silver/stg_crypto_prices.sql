{{
    config(
        materialized='view',
        tags=['silver']
    )
}}

select
    coin_id,
    lower(trim(source)) as source,
    lower(trim(symbol)) as symbol,
    price_usd::numeric(20, 8) as price_usd,
    market_cap::numeric(30, 2) as market_cap,
    change_24h::numeric(10, 4) as change_24h,
    recorded_at at time zone 'utc' as recorded_at
from {{ source('raw', 'crypto_prices') }}
where coin_id is not null
  and source is not null
  and price_usd is not null
  and price_usd > 0
  and recorded_at is not null
