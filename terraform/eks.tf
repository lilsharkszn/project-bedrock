module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "project-bedrock-cluster" # Enforced explicit Capstone constraint
  cluster_version = "1.34"

  # Keeping the cluster endpoint private for worker nodes, but public for local kubectl access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Enable modern AWS Native Access Entries instead of the legacy aws-auth ConfigMap
  authentication_mode = "API_AND_CONFIG_MAP"

  # Core Requirement 4.4: Control Plane Logging enabled
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Managed Node Groups (Worker Nodes)
  eks_managed_node_groups = {
    initial = {
      ami_type       = "AL2023_x86_64_STANDARD" # Optimized Amazon Linux 2023 for EKS
      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2

      # Ensure worker nodes run strictly in our secure private subnets
      subnet_ids = module.vpc.private_subnets

      labels = {
        Environment = "production"
        Project     = "karatu-2025-capstone"
      }
    }
  }

  tags = {
    ClusterRole = "Master"
    Project     = "karatu-2025-capstone" # Mandatory Capstone Tag
  }
}
