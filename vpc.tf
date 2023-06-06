
data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}


locals {

  name   = var.env_name
  region = var.region


  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    environment = var.env_name

  }
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0.0"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 52)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  tags = local.tags
}
