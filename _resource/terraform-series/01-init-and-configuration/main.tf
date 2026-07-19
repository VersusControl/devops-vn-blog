# Chapter 1 — Initializing and writing Terraform configuration.
#
# Modern version: version pinning + a `data` source to resolve the latest
# Ubuntu 24.04 LTS (Noble) AMI instead of hard-coding an AMI ID.

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

# The `data` block queries AWS through the provider and returns information about
# an existing resource. It does NOT create anything. Here we ask for the most
# recent Ubuntu 24.04 (Noble) server image published by Canonical.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account id

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "hello" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  tags = {
    Name = "HelloWorld"
  }
}
