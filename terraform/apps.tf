# ==========================================
# DYNAMIC AWS IAM AUTOMATION FOR ALB
# ==========================================
data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "bedrock" {
  name       = "project-bedrock-cluster"
  depends_on = [module.eks]
}

locals {
  oidc_provider_url = replace(data.aws_eks_cluster.bedrock.identity[0].oidc[0].issuer, "https://", "")
}

resource "aws_iam_policy" "alb_controller_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy-Bedrock-V2"
  description = "Provides full permissions required by the AWS ALB Ingress Controller"
  policy      = file("${path.module}/alb_iam_policy.json")

  tags = {
    Project = "karatu-2025-capstone"
  }
}

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
# KUBERNETES NAMESPACE
# ==========================================
resource "kubernetes_namespace" "retail_app" {
  metadata {
    name = "retail-app"
  }

  depends_on = [module.eks]
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
    <<-HELMEOF
    fullnameOverride: catalog
    app:
      persistence:
        provider: mysql
        endpoint: ${aws_db_instance.mysql.address}:3306
        database: catalog
        secret:
          create: false
          name: catalog-db
    mysql:
      create: false
    HELMEOF
  ]

  depends_on = [
    aws_db_instance.mysql,
    kubernetes_secret.catalog_db,
    kubernetes_namespace.retail_app
  ]
}

resource "helm_release" "retail_store_orders" {
  name             = "retail-store-orders"
  chart            = "../apps/retail-store-sample-app/src/orders/chart"
  namespace        = "retail-app"
  create_namespace = true

  values = [
    <<-HELMEOF
    fullnameOverride: orders
    app:
      persistence:
        provider: postgresql
        endpoint: ${aws_db_instance.postgres.address}:5432
        database: orders
        secret:
          create: false
          name: orders-db
      messaging:
        provider: in-memory
    postgresql:
      create: false
    HELMEOF
  ]

  depends_on = [
    aws_db_instance.postgres,
    kubernetes_secret.orders_db,
    kubernetes_namespace.retail_app
  ]
}

resource "helm_release" "retail_store_carts" {
  name             = "carts"
  chart            = "../apps/retail-store-sample-app/src/cart/chart"
  namespace        = "retail-app"
  create_namespace = true

  values = [
    <<-HELMEOF
    fullnameOverride: carts
    app:
      persistence:
        provider: dynamodb
        dynamodb:
          tableName: items
          createTable: false
    dynamodb:
      create: false
    HELMEOF
  ]

  depends_on = [kubernetes_namespace.retail_app]
}

resource "helm_release" "retail_store_checkout" {
  name             = "checkout"
  chart            = "../apps/retail-store-sample-app/src/checkout/chart"
  namespace        = "retail-app"
  create_namespace = true

  values = [
    <<-HELMEOF
    fullnameOverride: checkout
    app:
      persistence:
        provider: redis
      endpoints:
        orders: http://orders:80
    redis:
      create: true
    HELMEOF
  ]

  depends_on = [
    kubernetes_namespace.retail_app,
    helm_release.retail_store_orders
  ]
}

resource "helm_release" "retail_store_ui" {
  name             = "ui"
  chart            = "../apps/retail-store-sample-app/src/ui/chart"
  namespace        = "retail-app"
  create_namespace = true

  values = [
    <<-HELMEOF
    fullnameOverride: ui
    app:
      endpoints:
        catalog: http://catalog:80
        carts: http://carts:80
        checkout: http://checkout:80
        orders: http://orders:80
    HELMEOF
  ]

  depends_on = [
    kubernetes_namespace.retail_app,
    helm_release.retail_store_catalog,
    helm_release.retail_store_orders,
    helm_release.retail_store_carts,
    helm_release.retail_store_checkout
  ]
}

# ==========================================
# INGRESS CONFIGURATION & CORE NETWORKING
# ==========================================

resource "kubernetes_service_account" "alb_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller_role.arn
    }
  }

  depends_on = [module.eks]
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  depends_on = [kubernetes_service_account.alb_sa]

  values = [
    <<-HELMEOF
    clusterName: project-bedrock-cluster
    vpcId: ${module.vpc.vpc_id}
    region: us-east-1
    serviceAccount:
      create: false
      name: aws-load-balancer-controller
    HELMEOF
  ]
}

resource "kubernetes_ingress_v1" "retail_ingress" {  
  depends_on = [  
    helm_release.aws_lb_controller,  
    helm_release.retail_store_ui,  
    null_resource.cluster_issuer  
  ]  
  
  metadata {  
    name      = "retail-store-ingress"  
    namespace = "retail-app"  
    annotations = {  
      "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
      "alb.ingress.kubernetes.io/group.name"        = "bedrock-retail"  
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
              name = "ui"  
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

# ==========================================
# CLOUDWATCH OBSERVABILITY EKS ADDON
# Required by spec section 4.4
# ==========================================
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = module.eks.cluster_name
  addon_name   = "amazon-cloudwatch-observability"

  depends_on = [module.eks]

  tags = {
    Project = "karatu-2025-capstone"
  }
}
