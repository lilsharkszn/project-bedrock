# Fetch active Availability Zones within our chosen region (us-east-1)
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "project-bedrock-vpc" # Enforced explicit Capstone constraint
  cidr = "10.0.0.0/16"

  # Split across two AZs for High Availability (HA)
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # Cost Optimization vs High Availability: One NAT Gateway shared across private subnets
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Crucial tags for AWS Load Balancer Controller dynamic subnet discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/project-bedrock-cluster" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/project-bedrock-cluster" = "shared"
  }

  tags = {
    NetworkLayer = "True"
    Project      = "karatu-2025-capstone" # Mandatory Capstone Tag
  }
}
