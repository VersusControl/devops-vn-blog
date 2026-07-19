# Chapter 2 — The lifecycle of a resource (Create / Read / Update / Delete).
#
# We use a single S3 bucket to walk through the CRUD lifecycle and resource drift.
# In AWS provider v4+ the monolithic `aws_s3_bucket` was split: sub-settings such
# as ACLs, versioning and website config now live in their own resources. For a
# plain bucket with tags, `aws_s3_bucket` on its own is all we need.

terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "terraform_bucket" {
  # Bucket names are globally unique. `bucket` is a Force New attribute:
  # changing it makes Terraform destroy and recreate the bucket.
  bucket = "terraform-series-bucket"

  tags = {
    Name = "Terraform Series"
  }
}
