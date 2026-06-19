# ============================================
# Developer Read-Only IAM User
# ============================================

resource "aws_iam_user" "developer" {
  name = "bedrock-dev-view"
  path = "/"

  tags = {
    Project = "karatu-2025-capstone"
    Role    = "Developer-ReadOnly"
  }
}

# ============================================
# AWS Managed ReadOnly Policy
# ============================================

resource "aws_iam_user_policy_attachment" "read_only" {
  user       = aws_iam_user.developer.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ============================================
# Custom S3 Upload Permissions
# Required by grading instructions
# ============================================

resource "aws_iam_user_policy" "s3_upload" {
  name = "bedrock-dev-s3-upload-policy"
  user = aws_iam_user.developer.name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowAssetUploads"
        Effect = "Allow"

        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]

        Resource = [
          "arn:aws:s3:::${var.assets_bucket_name}/*"
        ]
      }
    ]
  })
}

# ============================================
# Programmatic Access Keys
# Required for grading deliverables
# ============================================

resource "aws_iam_access_key" "developer_keys" {
  user = aws_iam_user.developer.name
}

# ============================================
# Kubernetes RBAC — Map IAM user to view role
# Required: bedrock-dev-view can get pods
# but cannot delete them
# ============================================
resource "kubernetes_cluster_role_binding" "developer_view" {
  metadata {
    name = "bedrock-dev-view-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  subject {
    kind      = "User"
    name      = "bedrock-dev-view"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [module.eks]
}

# ============================================
# EKS Access Entry — Map IAM user to K8s
# ============================================
resource "aws_eks_access_entry" "developer" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_user.developer.arn
  type          = "STANDARD"

  depends_on = [module.eks]

  tags = {
    Project = "karatu-2025-capstone"
  }
}

resource "aws_eks_access_policy_association" "developer_view" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_user.developer.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.developer]
}

# ============================================
# Console Login Profile
# Required: grading requires console credentials
# ============================================
resource "aws_iam_user_login_profile" "developer_console" {
  user                    = aws_iam_user.developer.name
  password_reset_required = false

  lifecycle {
    ignore_changes = [password_length, password_reset_required, pgp_key]
  }
}
