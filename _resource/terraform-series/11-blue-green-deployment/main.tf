# Chapter 11 — Blue/Green Deployment for an Auto Scaling Group.
#
# The original chapter used the unmaintained `terraform-in-action/aws/bluegreen`
# module. This is a modern, self-contained equivalent:
#   * base  = VPC + ALB + two target groups + a weighted listener (the shared,
#             rarely-changing part).
#   * green/blue = an Auto Scaling Group per color (the Application part).
# The cutover is a single variable: `production` shifts 100% of the listener
# weight to the chosen color's target group.

provider "aws" {
  region = "us-west-2"
}

module "base" {
  source = "./modules/base"

  project    = "terraforminaction"
  production = var.production
}

module "green" {
  source = "./modules/autoscaling"

  label             = "green"
  app_version       = "v1.0"
  private_subnets   = module.base.private_subnets
  security_group_id = module.base.web_security_group_id
  target_group_arn  = module.base.target_group_arns["green"]
}

module "blue" {
  source = "./modules/autoscaling"

  label             = "blue"
  app_version       = "v2.0"
  private_subnets   = module.base.private_subnets
  security_group_id = module.base.web_security_group_id
  target_group_arn  = module.base.target_group_arns["blue"]
}

output "lb_dns_name" {
  value = module.base.lb_dns_name
}
