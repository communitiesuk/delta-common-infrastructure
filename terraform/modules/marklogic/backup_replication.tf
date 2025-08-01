# Replicate the weekly backups to another bucket that has Object Lock enabled to prevent accidental or malicious deletion.
# MarkLogic 10 cannot backup directly to an S3 bucket with Object Lock enabled as it does not send the Content-MD5 header.

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "backup_replication" {
  name               = "s3-backup-replication-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "backup_replication" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [module.weekly_backup_bucket.bucket_arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
      "s3:GetObjectRetention",
      "s3:GetObjectLegalHold",
    ]

    resources = ["${module.weekly_backup_bucket.bucket_arn}/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]

    resources = ["${var.backup_replication_bucket.arn}/*"]
  }
}

resource "aws_iam_policy" "backup_replication" {
  name   = "s3-backup-replication-${var.environment}"
  policy = data.aws_iam_policy_document.backup_replication.json
}

resource "aws_iam_role_policy_attachment" "backup_replication" {
  role       = aws_iam_role.backup_replication.name
  policy_arn = aws_iam_policy.backup_replication.arn
}

locals {
  replication_rule_id = "replicate-to-locked-bucket"
}

resource "aws_s3_bucket_replication_configuration" "backup_replication" {
  role   = aws_iam_role.backup_replication.arn
  bucket = module.weekly_backup_bucket.bucket

  rule {
    id = local.replication_rule_id

    filter {
      prefix = ""
    }

    status = "Enabled"

    destination {
      bucket        = var.backup_replication_bucket.arn
      storage_class = "GLACIER_IR"

      metrics {
        status = "Enabled"
      }
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }
}

resource "aws_s3_bucket_notification" "replication_notifications" {
  bucket = module.weekly_backup_bucket.bucket

  topic {
    topic_arn = var.alarms_sns_topic_arn
    events    = ["s3:Replication:OperationFailedReplication"]
  }
}
