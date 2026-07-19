# Chapter 4 — Deploy a static website to S3.
#
# Modernized for AWS provider v6. Important change vs. the original 2022 code:
# S3 now DISABLES ACLs by default (Object Ownership = BucketOwnerEnforced) and
# blocks public access, so the old `aws_s3_bucket_acl { acl = "public-read" }`
# approach no longer works. The modern, recommended way to make objects publicly
# readable for a static site is a *bucket policy* plus an explicit
# `aws_s3_bucket_public_access_block` that permits public policies.
#
# NOTE: For production static sites, the current best practice is CloudFront with
# Origin Access Control (OAC) in front of a PRIVATE bucket. We keep the S3 website
# endpoint here because this chapter is specifically about S3 website hosting.

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

resource "aws_s3_bucket" "static" {
  bucket        = "terraform-series-bai3"
  force_destroy = true

  tags = {
    Project = "Terraform Series"
  }
}

# S3 blocks public access by default. Allow a public *bucket policy* (but still
# keep ACLs blocked — we don't use ACLs at all).
resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_policy" "static" {
  bucket = aws_s3_bucket.static.id
  policy = file("${path.module}/s3_static_policy.json")

  # The policy can only be attached once public policies are allowed.
  depends_on = [aws_s3_bucket_public_access_block.static]
}

locals {
  mime_types = {
    html  = "text/html"
    css   = "text/css"
    ttf   = "font/ttf"
    woff  = "font/woff"
    woff2 = "font/woff2"
    js    = "application/javascript"
    map   = "application/javascript"
    json  = "application/json"
    jpg   = "image/jpeg"
    png   = "image/png"
    svg   = "image/svg+xml"
    eot   = "application/vnd.ms-fontobject"
  }
}

# Upload every file under static-web/ to the bucket. `for_each` keys each object
# by its path so adds/removes are tracked precisely.
resource "aws_s3_object" "object" {
  for_each = fileset(path.module, "static-web/**/*")

  bucket       = aws_s3_bucket.static.id
  key          = replace(each.value, "static-web/", "")
  source       = "${path.module}/${each.value}"
  etag         = filemd5("${path.module}/${each.value}")
  content_type = lookup(local.mime_types, element(split(".", each.value), length(split(".", each.value)) - 1), "application/octet-stream")
}
