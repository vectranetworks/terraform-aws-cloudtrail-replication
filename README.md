# Cloudtrail Data

This is a Terraform module is for creating AWS Cloudtrails for two cases:
- as a generator of Cloudtrail events, for testing bucket replication (sending side)
- for inspecting replication buckets, to debug replication issues (receiving side)

Use case: S3 Bucket Events Debugger:

```terraform
module "cloudtrail_dataplane" {
  providers = {
    aws = aws.eu-west-1
  }
  source = "../../../modules/cloudtrail_datatrail"
  basename = "test"
  environment = var.environment
  monitored_bucket_arns = ["<arns of the bucket being monitored>"]
}
```

Use case: A Cloudtrail Source, S3 bucket, and Replication Setup:

```terraform
module "cloudtrail_generator" {
  providers = {
    aws = aws.eu-west-2
  }
  source = "../../../modules/cloudtrail_datatrail"
  basename = "debug"
  environment = "test"
  replication_bucket_destination_arn = "<destination bucket arn>"
  replication_account_destination = "<12 digit destination account id>"
}
```