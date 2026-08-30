output "region" {
  description = "AWS region."
  value       = var.region
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  description = "ECR repository URL — push the site image here."
  value       = aws_ecr_repository.website.repository_url
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN for the Ingress (empty unless create_acm_certificate=true)."
  value       = var.create_acm_certificate ? aws_acm_certificate.this[0].arn : ""
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the new cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
