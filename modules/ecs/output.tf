output "ecs_cluster_id" {
  description = "The ID of the ECS cluster."
  value       = aws_ecs_cluster.main.id
}

output "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role."
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "alb_arn" {
  description = "The ARN of the ALB."
  value       = aws_lb.alb.arn
}

output "alb_dns_name" {
  description = "The DNS name of the ALB."
  value       = aws_lb.alb.dns_name
}

output "alb_http_listener_port" {
  description = "The port of the HTTP listener."
  value       = aws_lb_listener.http.port
}
