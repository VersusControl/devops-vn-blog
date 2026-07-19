provider "aws" {
  region = "us-west-2"
}

# Lambda@Edge functions must be created in us-east-1.
provider "aws" {
  region = "us-east-1"
  alias  = "us_east_1"
}

locals {
  s3_origin_id         = "access-identity-s3-pro"
  s3_origin_staging_id = "access-identity-s3-pre-pro"
}

output "dns" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "s3" {
  value = {
    pro     = aws_s3_bucket.s3_pro.bucket_domain_name
    pre_pro = aws_s3_bucket.s3_pre_pro.bucket_domain_name
  }
}
