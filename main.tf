terraform {
  required_version = ">= 0.13.6"
  required_providers {
    aws = ">= 3.27"
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  role_name   = "${var.bucket_name}CloudtrailReplication"
}

data aws_iam_policy_document source_cloudtrail_bucket_resource_policy {

  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      identifiers = ["cloudtrail.amazonaws.com"]
      type        = "Service"
    }
    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${var.bucket_name}"]
  }
  statement {
    sid = "AWSCloudTrailWrite"
    principals {
      identifiers = ["cloudtrail.amazonaws.com"]
      type        = "Service"
    }
    actions = ["s3:PutObject"]
    resources = [
      "arn:aws:s3:::${var.bucket_name}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]
    condition {
      test     = "StringEquals"
      values   = ["bucket-owner-full-control"]
      variable = "s3:x-amz-acl"
    }
  }
}

resource "aws_s3_bucket" "source_cloudtrail_bucket" {
  bucket        = var.bucket_name
  force_destroy = true
  # this role is defined further down the file, around line 100
  policy = data.aws_iam_policy_document.source_cloudtrail_bucket_resource_policy.json
  versioning {
    enabled = true
  }

  # this is the bucket's replication configuration
  # for versions lower than Terraform 13, it will need to be converted back to
  # the non-dynamic format
  dynamic "replication_configuration" {
    for_each = var.replication_bucket_destination_arn != "" ? [1] : []
    content {
      role = aws_iam_role.bucket_replication_role[0].arn
      rules {
        id     = "cloudtrail_replication"
        status = "Enabled"
        destination {
          account_id    = var.replication_account_destination
          bucket        = var.replication_bucket_destination_arn
          storage_class = "STANDARD_IA"
          access_control_translation {
            owner = "Destination"
          }
        }
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "source_cloudtrail_bucket_access_block" {
  bucket                  = aws_s3_bucket.source_cloudtrail_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudtrail" "cloudtrail" {
  name                          = "${var.bucket_name}_trail"
  s3_bucket_name                = aws_s3_bucket.source_cloudtrail_bucket.id
  include_global_service_events = false
  is_multi_region_trail         = false

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type = "AWS::S3::Object"

      # Make sure to append a trailing '/' to your ARN if you want
      # to monitor all objects in a bucket.
      values = [
        for arn in var.monitored_bucket_arns :
        "${trimsuffix(arn, "/")}/" # enforce trailing slashes
      ]
    }
  }
}

#
#  Begin replication role definition
#

resource "aws_iam_role" "bucket_replication_role" {
  count              = var.replication_bucket_destination_arn != "" ? 1 : 0
  name               = local.role_name
  path               = "/service-role/"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

# The documentation for the policy below varies in AWS official documentation,
# depending on when it was published. To be safe (working replication minimum), this is
# copied exactly from a replication rule's "Create a new role" option
# created VIA the AWS console between eu-west-2 -> eu-west-1
# on 2020-02-11, including all locations of the source and destination buckets in the policy.
data aws_iam_policy_document source_bucket_replication_role_permissions {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetReplicationConfiguration",
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
      "s3:GetObjectRetention",
      "s3:GetObjectLegalHold",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::${var.bucket_name}", # no trailing slash
      "arn:aws:s3:::${var.bucket_name}/*",
      var.replication_bucket_destination_arn,
      "${var.replication_bucket_destination_arn}/*",
    ]
  }
  statement {
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
      "s3:ObjectOwnerOverrideToBucketOwner"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
      "${var.replication_bucket_destination_arn}/*",
    ]
  }
}

# IAM replication policy #
resource "aws_iam_policy" "source_bucket_replication_policy" {
  count  = var.replication_bucket_destination_arn != "" ? 1 : 0
  name   = local.role_name
  policy = data.aws_iam_policy_document.source_bucket_replication_role_permissions.json
}

resource "aws_iam_role_policy_attachment" "source_bucket_replication_policy_attachment" {
  count      = var.replication_bucket_destination_arn != "" ? 1 : 0
  role       = aws_iam_role.bucket_replication_role[0].name
  policy_arn = aws_iam_policy.source_bucket_replication_policy[0].arn
}

#
#  End replication role definition
#