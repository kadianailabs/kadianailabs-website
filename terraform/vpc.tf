# ─────────────────────────────────────────────────────────
# VPC with public + private subnets across 3 AZs.
# Public subnets host the ALB; private subnets host the nodes.
# ─────────────────────────────────────────────────────────
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr
  azs  = local.azs

  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k + 8)]

  enable_nat_gateway   = true
  single_nat_gateway   = true # cost-saving for a low-traffic static site
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags the AWS Load Balancer Controller needs for subnet auto-discovery.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${local.name}-eks"   = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${local.name}-eks"   = "shared"
  }
}
