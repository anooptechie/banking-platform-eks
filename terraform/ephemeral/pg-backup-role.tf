data "aws_caller_identity" "current" {}

locals {
  pg_backup_bucket = "banking-platform-pg-backups-${data.aws_caller_identity.current.account_id}"
}

# IRSA role for the Postgres pods (service account banking/banking-pg).
# The name is fixed on purpose so the ARN can be committed to Git.
data "aws_iam_policy_document" "pg_backup_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:banking:banking-pg"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "pg_backup" {
  name               = "banking-platform-pg-backup"
  assume_role_policy = data.aws_iam_policy_document.pg_backup_assume.json
}

data "aws_iam_policy_document" "pg_backup" {
  statement {
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::${local.pg_backup_bucket}"]
  }
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["arn:aws:s3:::${local.pg_backup_bucket}/*"]
  }
}

resource "aws_iam_role_policy" "pg_backup" {
  name   = "pg-backup-s3"
  role   = aws_iam_role.pg_backup.id
  policy = data.aws_iam_policy_document.pg_backup.json
}

output "pg_backup_role_arn" {
  value = aws_iam_role.pg_backup.arn
}
