# ==========================================
# DYNAMIC AWS IAM AUTOMATION FOR ALB
# ==========================================
data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "bedrock" {
  name       = "project-bedrock-cluster"
  depends_on = [module.eks] # Blocks evaluation until cluster resources physically exist
}

locals {
  # Strip "https://" from the OIDC URL for the IAM policy condition
  oidc_provider_url = replace(data.aws_eks_cluster.bedrock.identity[0].oidc[0].issuer, "https://", "")
}

# Automatically fetch the complete, official AWS Load Balancer Controller IAM Policy
data "http" "alb_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb_controller_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy-Bedrock-V2"
  description = "Provides full permissions required by the AWS ALB Ingress Controller"
  policy      = data.http.alb_iam_policy.response_body # Restores complete SG, WAF, and Target Group matrix

  tags = {
    Project = "karatu-2025-capstone"
  }
}

# Create the IAM Role tied to the specific Kubernetes ServiceAccount
resource "aws_iam_role" "alb_controller_role" {
  name = "AmazonEKSLoadBalancerControllerRole-Bedrock"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider_url}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller",
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Project = "karatu-2025-capstone"
  }
}

resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  role       = aws_iam_role.alb_controller_role.name
  policy_arn = aws_iam_policy.alb_controller_policy.arn
}

# ==========================================
# KUBERNETES DEPLOYMENTS (MICROSERVICES)
# ==========================================

resource "helm_release" "retail_store_catalog" {
  name             = "catalog"
  chart            = "../apps/retail-store-sample-app/src/catalog/chart"
  namespace        = "retail-app"
  create_namespace = true

  values = [
    file("${path.module}/../apps/retail-store-sample-app/bedrock-values.yaml")
  ]
}

resource "helm_release" "retail_store_orders" {
  name      = "retail-store-orders"
  chart     = "../apps/retail-store-sample-app/src/orders/chart"
  namespace = "retail-app"

  values = [
    file("${path.module}/../apps/retail-store-sample-app/bedrock-values.yaml")
  ]
}

# Resolved Bug: Added the mandatory missing UI Application Deployment required by Section 4.2
resource "helm_release" "retail_store_ui" {
  name      = "ui"
  chart     = "../apps/retail-store-sample-app/src/ui/chart"
  namespace = "retail-app"

  values = [
    file("${path.module}/../apps/retail-store-sample-app/bedrock-values.yaml")
  ]
}

# ==========================================
# INGRESS CONFIGURATION & CORE NETWORKING
# ==========================================

resource "kubernetes_ingress_v1" "retail_ingress" {
  depends_on = [helm_release.aws_lb_controller, helm_release.retail_store_ui]

  metadata {
    name      = "retail-store-ingress"
    namespace = "retail-app"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"  = "ip"
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}]"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = "altsoe0254423.ddns.net"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "ui" # Routes strictly to the UI layer 
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

output "alb_url" {
  value = try(kubernetes_ingress_v1.retail_ingress.status[0].load_balancer[0].ingress[0].hostname, "ALB provisioning in progress...")
}

# 1. Create the Service Account with exact IAM role mapping
resource "kubernetes_service_account" "alb_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller_role.arn
    }
  }
}

# 2. Deploy the controller via Helm with explicit structural mappings
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  depends_on = [kubernetes_service_account.alb_sa]

  values = [
    <<-EOF
    clusterName: project-bedrock-cluster
    vpcId: ${module.vpc.vpc_id}
    region: us-east-1
    serviceAccount:
      create: false
      name: aws-load-balancer-controller
    EOF
  ]
}
