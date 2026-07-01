-- Freshness: minutes since last tick per source (SLA default 10 min)
SELECT
    source,
    max(recorded_at) AS last_event_at,
    round(extract(epoch FROM (NOW() - max(recorded_at))) / 60.0, 1) AS minutes_stale,
    CASE
        WHEN extract(epoch FROM (NOW() - max(recorded_at))) / 60.0 <= 10 THEN 'OK'
        WHEN extract(epoch FROM (NOW() - max(recorded_at))) / 60.0 <= 30 THEN 'WARN'
        ELSE 'FAIL'
    END AS sla_status
FROM raw.crypto_prices
WHERE recorded_at >= NOW() - INTERVAL '24 hours'
GROUP BY source
ORDER BY source;
