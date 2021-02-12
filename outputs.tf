output "unified" {
  value = {
    bucket = {
      arn  = aws_s3_bucket.source_cloudtrail_bucket.arn
      name = aws_s3_bucket.source_cloudtrail_bucket.id
    }
    trail = {
      name = aws_cloudtrail.cloudtrail.name
    }
  }
}