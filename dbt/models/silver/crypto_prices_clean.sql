{{
    config(
        materialized='incremental',
        unique_key=['coin_id', 'source', 'recorded_at'],
        on_schema_change='sync_all_columns',
        tags=['silver']
    )
}}

select distinct on (coin_id, source, recorded_at)
    coin_id,
    source,
    symbol,
    price_usd,
    market_cap,
    change_24h,
    recorded_at
from {{ ref('stg_crypto_prices') }}
{% if is_incremental() %}
where recorded_at > (select coalesce(max(recorded_at), timestamp '1970-01-01') from {{ this }})
{% endif %}
order by coin_id, source, recorded_at
