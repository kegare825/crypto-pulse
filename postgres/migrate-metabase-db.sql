-- Run if Metabase fails to start (DB missing on existing volumes):
-- docker exec -i crypto-pulse-postgres psql -U pulse -d cryptopulse -c "CREATE DATABASE metabase OWNER pulse;"

SELECT 'CREATE DATABASE metabase OWNER pulse'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'metabase')\gexec
