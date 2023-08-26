data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"

  name                 = "lt-demo-vpc-${local.env}"
  cidr                 = var.vpc_cidr[local.env]
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = var.public_subnet_cidrs[local.env]
  enable_dns_hostnames = true
  enable_dns_support   = true
}
