variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "services" {
  type = map(object({
    image = string
    port  = number
  }))
  default = {
    prometheus = {
      image = "prom/prometheus:latest"
      port  = 9090
    }
  }
}

variable "task_definitions" {
  type = list(object({
    arn = string
  }))
}

variable "target_groups" {
  type = list(object({
    arn = string
  }))
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
