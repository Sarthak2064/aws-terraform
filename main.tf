provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source             = "./modules/vpc"
  cidr_block         = var.cidr_block
  vpc_name           = var.vpc_name
  public_subnet_ids  = var.public_subnet_ids
  private_subnet_ids = var.private_subnet_ids
  availability_zones = var.availability_zones
}

module "ecs" {
  source             = "./modules/ecs"
  vpc_id             = module.vpc.vpc_id
  public_subnets     = module.vpc.public_subnet_ids
  private_subnets    = module.vpc.private_subnet_ids
  availability_zones = module.vpc.availability_zones
  task_definitions   = var.task_definitions
  target_groups      = var.target_groups
}


terraform {
  backend "s3" {
    bucket  = "terraform-state-bucket-kan67" # Your S3 bucket name
    key     = "terraform/state"              # Path within the bucket for the state file
    region  = "us-east-1"                    # The AWS region where your bucket is located
    encrypt = true                           # Encrypt state file with SSE
  }
}
