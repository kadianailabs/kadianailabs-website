variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name, used for tagging and resource naming."
  type        = string
  default     = "kadianai-website"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_version" {
  description = "EKS Kubernetes control-plane version."
  type        = string
  default     = "1.30"
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 4
}

variable "domain_name" {
  description = "Primary domain for the site (used for the ACM cert / Route53). Leave empty to skip cert creation."
  type        = string
  default     = "kadianailabs.com"
}

variable "create_acm_certificate" {
  description = "Whether Terraform should request an ACM cert for domain_name (requires a Route53 hosted zone)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags applied to all resources."
  type        = map(string)
  default     = {}
}
