# Example: S3 Standard Backend with native state locking (Terraform 1.10+).
#
# This file is illustrative — `terraform init` would try to reach the real S3
# bucket, so it isn't meant to be applied as-is. Replace the bucket/key/region
# with your own.
terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "state-bucket"
    key          = "team/rocket"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true # S3-native locking — no DynamoDB table needed
  }
}
