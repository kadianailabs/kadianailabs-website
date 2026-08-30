# ─────────────────────────────────────────────────────────
# EKS cluster + managed node group (private subnets).
# Uses IRSA so in-cluster controllers get scoped IAM permissions.
# ─────────────────────────────────────────────────────────
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = "${local.name}-eks"
  cluster_version = var.cluster_version

  # Public API endpoint so you can run kubectl from your workstation.
  # Lock this down (endpoint_public_access_cidrs) or go private for prod hardening.
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
  }

  eks_managed_node_group_defaults = {
    ami_type = "AL2023_x86_64_STANDARD"
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      desired_size   = var.node_desired_size
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      capacity_type  = "ON_DEMAND"

      labels = {
        role = "general"
      }
    }
  }
}
