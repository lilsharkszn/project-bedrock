output "cluster_endpoint" {
  description = "EKS control plane API endpoint address"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "The assigned name of our EKS Cluster"
  value       = module.eks.cluster_name
}

output "region" {
  description = "Target deployment region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "Identifier of the provisioned production VPC"
  value       = module.vpc.vpc_id
}

output "assets_bucket_name" {
  description = "The uniquely generated asset bucket name"
  value       = aws_s3_bucket.assets.id
}

output "developer_access_key_id" {
  description = "The programmatic Access Key ID for the developer account"
  value       = aws_iam_access_key.developer_keys.id
}

output "developer_secret_access_key" {
  description = "The programmatic Secret Access Key for the developer account"
  value       = aws_iam_access_key.developer_keys.secret
  sensitive   = true
}
output "custom_host_address" {
  description = "The verified external routing domain for the retail application"
  value       = "altsoe0254423.ddns.net"
}

