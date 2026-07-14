data "aws_iam_policy_document" "flink_lake_writer" {
  statement {
    sid    = "ListLakeBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.lake.arn]
  }

  statement {
    sid    = "ReadWriteLakeObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${aws_s3_bucket.lake.arn}/${var.lake_raw_prefix}/*"]
  }
}

resource "aws_iam_policy" "flink_lake_writer" {
  name        = "${var.project_name}-flink-lake-writer"
  description = "Least-privilege write to the crypto-pulse raw lake prefix (LocalStack demo)."
  policy      = data.aws_iam_policy_document.flink_lake_writer.json
}

resource "aws_iam_user" "flink_lake_writer" {
  name = "${var.project_name}-flink-lake-writer"
}

resource "aws_iam_user_policy_attachment" "flink_lake_writer" {
  user       = aws_iam_user.flink_lake_writer.name
  policy_arn = aws_iam_policy.flink_lake_writer.arn
}
