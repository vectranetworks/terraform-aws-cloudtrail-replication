variable "bucket_name" {
  type        = string
  description = "Name of the bucket that CloudTrail will use. This must be a new bucket, not an existing bucket."
}

variable "monitored_bucket_arns" {
  type        = list(string)
  default     = []
  description = "ARNs of other S3 bucket to monitor for events. Do not include the CloudTrail bucket."
}

variable "replication_bucket_destination_arn" {
  type        = string
  default     = ""
  description = "If the CloudTrail bucket is being replicated, the ARN of the bucket being replicated to."
}

variable "replication_account_destination" {
  type        = string
  default     = ""
  description = "If the CloudTrail bucket is being replicated, the twelve digit AWS account number the bucket belongs to."
}