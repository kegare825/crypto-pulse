# Terraform — LocalStack (no AWS account required)

Infrastructure-as-code for the **storage slice** of Crypto Pulse: S3 lake bucket + IAM policy for Flink dual-write. Targets [LocalStack](https://localstack.cloud/) on `localhost:4566` — same AWS provider you'd use in production, zero cloud spend.

## What this models

| Resource | Production analogue | Compose equivalent today |
|----------|---------------------|--------------------------|
| `aws_s3_bucket.lake` | S3 data lake bucket | MinIO `crypto-pulse` bucket |
| `aws_s3_object` prefix marker | Bucket layout contract | `LAKE_RAW_PREFIX=raw/crypto_prices` |
| `aws_iam_user.flink_lake_writer` | Task role for Flink sink | `minioadmin` static creds (demo only) |

Kafka topics and RDS remain in `docker-compose.yml` / `ci/kafka_init_topics.sh` for now — MSK/RDS modules would be a separate Phase D step against real AWS.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- Docker (for LocalStack)

## Quick start

```bash
# 1. Start LocalStack (compose profile — does not start the full pipeline)
docker compose --profile terraform up -d localstack

# 2. Plan / apply against localhost
bash scripts/terraform_local.sh plan
bash scripts/terraform_local.sh apply   # optional — creates bucket + IAM in LocalStack

# 3. Tear down LocalStack when done
docker compose --profile terraform down
```

`scripts/terraform_local.sh` waits for LocalStack health, runs `terraform init`, then forwards arguments (`plan`, `apply`, `destroy`) to Terraform in `terraform/`.

## Manual commands

```bash
docker compose --profile terraform up -d localstack

cd terraform
terraform init
terraform plan
terraform apply   # creates resources in LocalStack only
```

To verify the bucket from the host:

```bash
aws --endpoint-url=http://localhost:4566 s3 ls s3://crypto-pulse/
```

(Requires AWS CLI; use any access key — LocalStack ignores credentials in dev mode.)

## CI

The **Terraform (LocalStack)** job in `.github/workflows/ci.yml` runs `terraform init`, `validate`, and `plan` on every PR. It does **not** `apply` — no persistent cloud state, no AWS credentials.

## Moving to real AWS later

1. Remove or override `endpoints` in `versions.tf` (or use a `prod` workspace with a separate `providers.tf`).
2. Point `localstack_endpoint` at real AWS (drop the variable; use default provider chain).
3. Add remote state (S3 + DynamoDB lock) and wire RDS/MSK modules.
4. Inject credentials via OIDC / IAM roles in CI — never commit keys.

See [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md#scaling--cost) for rough monthly cost if this stack were lifted to managed AWS.
