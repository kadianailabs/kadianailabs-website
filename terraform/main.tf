# ─────────────────────────────────────────────────────────
# Providers, shared locals, and data sources.
# ─────────────────────────────────────────────────────────
provider "aws" {
  region = var.region
  default_tags {
    tags = local.common_tags
  }
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name = var.project

  # Use three AZs for HA (control plane + spread node groups).
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}

# ── Authenticate the k8s + helm providers against the EKS cluster ──
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
