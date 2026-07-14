output "lake_bucket_name" {
  description = "S3 bucket hosting the raw Parquet lake."
  value       = aws_s3_bucket.lake.bucket
}

output "lake_bucket_arn" {
  description = "ARN of the lake bucket."
  value       = aws_s3_bucket.lake.arn
}

output "lake_raw_prefix" {
  description = "Hive-style prefix under which Flink writes Parquet."
  value       = var.lake_raw_prefix
}

output "flink_lake_writer_user" {
  description = "IAM user intended for Flink S3/MinIO sink credentials in cloud deployments."
  value       = aws_iam_user.flink_lake_writer.name
}

output "localstack_endpoint" {
  description = "Endpoint passed to the AWS provider (for documentation / smoke tests)."
  value       = var.localstack_endpoint
}
