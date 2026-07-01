-- Freshness: minutes since last tick per source (SLA default 10 min)
SELECT source, last_event_at, minutes_stale, sla_status
FROM gold.mart_freshness_by_source
ORDER BY source;
