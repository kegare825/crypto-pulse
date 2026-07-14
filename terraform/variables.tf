variable "aws_region" {
  description = "AWS region (LocalStack accepts any valid region string)."
  type        = string
  default     = "eu-west-1"
}

variable "localstack_endpoint" {
  description = "LocalStack edge URL. Use http://localhost:4566 from the host, http://localstack:4566 inside compose network."
  type        = string
  default     = "http://localhost:4566"
}

variable "project_name" {
  description = "Prefix for resource names in the lake module."
  type        = string
  default     = "crypto-pulse"
}

variable "lake_bucket_name" {
  description = "S3 bucket for raw Parquet archive (mirrors MINIO_BUCKET in docker-compose)."
  type        = string
  default     = "crypto-pulse"
}

variable "lake_raw_prefix" {
  description = "Object prefix for Flink Parquet dual-write (mirrors LAKE_RAW_PREFIX)."
  type        = string
  default     = "raw/crypto_prices"
}
