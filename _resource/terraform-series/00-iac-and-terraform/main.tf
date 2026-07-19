# "Hello Terraform!" — create a single EC2 instance on AWS.
#
# This is the modern (Terraform 1.9+, AWS provider v6) version of the very first
# example in the series. Compared to the original 2022 code it:
#   * pins Terraform and the AWS provider with a `required_providers` block
#   * looks up the latest Amazon Linux 2023 AMI with a data source instead of
#     hard-coding an AMI ID that goes stale and is region-specific
#   * uses a current-generation instance type (t3.micro)

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

# Look up the latest Amazon Linux 2023 AMI owned by Amazon.
# Using a data source keeps the config portable across regions and always
# resolves to a patched, up-to-date image.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "hello" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"

  tags = {
    Name = "HelloWorld"
  }
}
