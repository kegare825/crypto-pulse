#!/usr/bin/env bash
# Run Terraform against LocalStack (no AWS account). Usage:
#   bash scripts/terraform_local.sh plan
#   bash scripts/terraform_local.sh apply
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE="${COMPOSE_CMD:-docker compose}"
LOCALSTACK_URL="${LOCALSTACK_URL:-http://localhost:4566}"

cd "${ROOT}"

echo "=== Starting LocalStack (profile: terraform) ==="
${COMPOSE} --profile terraform up -d localstack

echo "=== Waiting for LocalStack health ==="
for _ in $(seq 1 40); do
  if curl -sf "${LOCALSTACK_URL}/_localstack/health" >/dev/null 2>&1; then
    echo "LocalStack is ready."
    break
  fi
  sleep 2
done

if ! curl -sf "${LOCALSTACK_URL}/_localstack/health" >/dev/null 2>&1; then
  echo "LocalStack did not become healthy at ${LOCALSTACK_URL}" >&2
  exit 1
fi

cd "${ROOT}/terraform"
terraform init -input=false

if [[ $# -eq 0 ]]; then
  set -- plan
fi

terraform "$@"
