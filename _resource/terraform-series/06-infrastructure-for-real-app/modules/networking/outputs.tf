output "vpc" {
  description = "The whole VPC module object (vpc_id, subnets, database_subnet_group, ...)"
  value       = module.vpc
}

output "sg" {
  description = "Security group ids for the load balancer, web tier and database"
  value = {
    lb  = module.alb_sg.security_group_id
    web = module.web_sg.security_group_id
    db  = module.db_sg.security_group_id
  }
}
