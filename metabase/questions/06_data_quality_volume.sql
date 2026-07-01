-- Row counts across pipeline zones (gold mart — Metabase schema gold only)
SELECT zone, source, row_count
FROM gold.mart_zone_volume
ORDER BY zone, source;
