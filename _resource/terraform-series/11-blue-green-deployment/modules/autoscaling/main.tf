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

resource "aws_launch_template" "web" {
  name_prefix   = "${var.label}-"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [var.security_group_id]

  user_data = base64encode(templatefile("${path.module}/run.sh.tftpl", {
    label       = var.label
    app_version = var.app_version
  }))
}

resource "aws_autoscaling_group" "web" {
  name                = "${var.label}-asg"
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  vpc_zone_identifier = var.private_subnets
  target_group_arns   = [var.target_group_arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  tag {
    key                 = "Name"
    value               = "${var.label}-${var.app_version}"
    propagate_at_launch = true
  }
}
