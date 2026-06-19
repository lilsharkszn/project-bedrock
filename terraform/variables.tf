variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "The target AWS region dictated by the project standards."
}

variable "cluster_name" {
  type        = string
  default     = "project-bedrock-cluster"
  description = "The exact name required for the EKS cluster."
}

variable "vpc_name" {
  type        = string
  default     = "project-bedrock-vpc"
  description = "The exact value required for the VPC Name Tag."
}

variable "student_id" {
  type        = string
  default     = "alt-soe-025-4423"
  description = "Sanitized student ID used for unique naming constraints."
}

variable "app_namespace" {
  type        = string
  default     = "retail-app"
  description = "Kubernetes namespace for the microservices application."
}

variable "assets_bucket_name" {
  type        = string
  default     = "bedrock-assets-hassan-alt-soe-025-4423"
  description = "Unique S3 assets bucket name for this deployment, bedrock-asset-alt-soe-025-4423 was attached to previous aws account"
}
