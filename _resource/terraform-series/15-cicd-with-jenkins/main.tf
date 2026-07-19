# Chapter 15 — CI/CD with Jenkins. State is stored in the S3 backend built in
# chapter 8. Replace <ACCOUNT_ID> and the role/bucket names with your own.
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "terraform-series-s3-backend"
    key          = "terraform-jenkins"
    region       = "us-west-2"
    encrypt      = true
    role_arn     = "arn:aws:iam::<ACCOUNT_ID>:role/Terraform-SeriesS3BackendRole"
    use_lockfile = true # S3-native locking (replaces the old dynamodb_table)
  }
}

provider "aws" {
  region = "us-west-2"
}

data "aws_ami" "ami" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "server" {
  ami           = data.aws_ami.ami.id
  instance_type = "t3.micro"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "Server"
  }
}

output "public_ip" {
  value = aws_instance.server.public_ip
}
