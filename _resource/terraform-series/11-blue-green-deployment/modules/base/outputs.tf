output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "web_security_group_id" {
  value = module.web_sg.security_group_id
}

output "target_group_arns" {
  description = "Map of color => target group ARN"
  value       = { for k, tg in aws_lb_target_group.color : k => tg.arn }
}

output "lb_dns_name" {
  value = aws_lb.this.dns_name
}
