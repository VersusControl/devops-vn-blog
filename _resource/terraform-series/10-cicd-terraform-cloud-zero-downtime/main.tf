provider "aws" {
  region = var.region
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

resource "aws_instance" "ansible_server" {
  ami           = data.aws_ami.ami.id
  instance_type = "t3.small"

  # Zero-downtime: create the replacement before destroying the old instance
  # when a force-new attribute (like ami) changes.
  lifecycle {
    create_before_destroy = true
  }
}
