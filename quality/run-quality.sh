#!/usr/bin/env bash
set -euo pipefail

echo "Running Great Expectations validations..."
exec python /app/validate.py
