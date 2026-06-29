{{
    config(
        tags=['gold']
    )
}}

with latest as (
    select *
    from {{ ref('mart_latest_prices_by_source') }}
),

pivot as (
    select
        coin_id,
        max(symbol) as symbol,
        max(case when source = 'coingecko' then price_usd end) as coingecko_price_usd,
        max(case when source = 'binance' then price_usd end) as binance_price_usd,
        max(case when source = 'coingecko' then last_recorded_at end) as coingecko_at,
        max(case when source = 'binance' then last_recorded_at end) as binance_at
    from latest
    group by 1
)

select
    coin_id,
    symbol,
    coingecko_price_usd,
    binance_price_usd,
    coingecko_at,
    binance_at,
    binance_price_usd - coingecko_price_usd as spread_usd,
    case
        when coingecko_price_usd > 0
        then round(
            100.0 * (binance_price_usd - coingecko_price_usd) / coingecko_price_usd,
            4
        )
    end as spread_pct
from pivot
where coingecko_price_usd is not null
  and binance_price_usd is not null
