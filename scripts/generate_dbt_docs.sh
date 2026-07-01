#!/usr/bin/env bash
# Generate dbt documentation site (lineage + data dictionary).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/docs/dbt"
DBT="${ROOT}/dbt"

cd "${DBT}"
dbt deps --profiles-dir .
dbt docs generate --profiles-dir .

rm -rf "${OUT}"
mkdir -p "${OUT}"
cp -r target/index.html target/catalog.json target/manifest.json target/run_results.json "${OUT}/" 2>/dev/null || true
cp -r target/assets "${OUT}/" 2>/dev/null || true

echo "dbt docs written to ${OUT}/"
echo "View locally: cd dbt && dbt docs serve --profiles-dir ."
