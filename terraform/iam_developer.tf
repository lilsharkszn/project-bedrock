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
          "arn:aws:s3:::bedrock-assets-${var.student_id}/*"
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
