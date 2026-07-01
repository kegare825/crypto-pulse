{{
    config(
        tags=['gold']
    )
}}

select
    source,
    last_recorded_at as last_event_at,
    round(
        extract(epoch from (current_timestamp - last_recorded_at)) / 60.0,
        1
    ) as minutes_stale,
    case
        when extract(epoch from (current_timestamp - last_recorded_at)) / 60.0 <= 10
            then 'OK'
        when extract(epoch from (current_timestamp - last_recorded_at)) / 60.0 <= 30
            then 'WARN'
        else 'FAIL'
    end as sla_status
from {{ ref('mart_latest_prices_by_source') }}
order by source
