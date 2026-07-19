data "aws_ami" "ami" {
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

# IAM role + instance profile for the EC2s. The book's `terraform-in-action/iip`
# module no longer exists, so we build the instance profile with plain resources.
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name               = "${var.project}-web-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "web" {
  name = "${var.project}-web-policy"
  role = aws_iam_role.web.id

  # Kept broad to mirror the tutorial. In production, scope these down to the
  # specific log groups / RDS resources the app needs.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:*", "rds:*"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.project}-web-profile"
  role = aws_iam_role.web.name
}

resource "aws_launch_template" "web" {
  name_prefix   = "web-"
  image_id      = data.aws_ami.ami.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [var.sg.web]

  iam_instance_profile {
    name = aws_iam_instance_profile.web.name
  }

  user_data = filebase64("${path.module}/run.sh")
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name    = var.project
  vpc_id  = var.vpc.vpc_id
  subnets = var.vpc.public_subnets

  # Reuse the SG created in the networking module.
  create_security_group = false
  security_groups       = [var.sg.lb]

  # v9 replaced http_tcp_listeners / target_groups(list) with listeners /
  # target_groups(map).
  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "web"
      }
    }
  }

  target_groups = {
    web = {
      name_prefix = "web-"
      protocol    = "HTTP"
      port        = 80
      target_type = "instance"
      # The ASG registers instances, so don't create a static attachment.
      create_attachment = false
    }
  }
}

resource "aws_autoscaling_group" "web" {
  name                = "${var.project}-asg"
  min_size            = 1
  max_size            = 3
  vpc_zone_identifier = var.vpc.private_subnets
  target_group_arns   = [module.alb.target_groups["web"].arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }
}
