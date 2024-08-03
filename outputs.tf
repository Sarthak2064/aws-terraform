output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets."
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "The IDs of the NAT Gateways."
  value       = module.vpc.nat_gateway_ids
}

output "ecs_cluster_id" {
  description = "The ID of the ECS cluster."
  value       = module.ecs.ecs_cluster_id
}

output "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role."
  value       = module.ecs.ecs_task_execution_role_arn
}

output "alb_arn" {
  description = "The ARN of the ALB."
  value       = module.ecs.alb_arn
}

output "alb_dns_name" {
  description = "The DNS name of the ALB."
  value       = module.ecs.alb_dns_name
}
