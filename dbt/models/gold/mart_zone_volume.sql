{{
    config(
        tags=['gold']
    )
}}

with raw_counts as (
    select
        'raw' as zone,
        source,
        count(*) as row_count
    from {{ source('raw', 'crypto_prices') }}
    where recorded_at >= current_timestamp - interval '24 hours'
    group by source
),

silver_counts as (
    select
        'silver' as zone,
        source,
        count(*) as row_count
    from {{ ref('crypto_prices_clean') }}
    where recorded_at >= current_timestamp - interval '24 hours'
    group by source
),

gold_counts as (
    select
        'gold_latest_by_source' as zone,
        source,
        count(*) as row_count
    from {{ ref('mart_latest_prices_by_source') }}
    group by source
)

select * from raw_counts
union all
select * from silver_counts
union all
select * from gold_counts
