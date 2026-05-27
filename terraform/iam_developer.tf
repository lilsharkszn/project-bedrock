# 1. Create the dedicated Developer IAM User
resource "aws_iam_user" "developer" {
  name = "bedrock-dev-view"
  path = "/"

  tags = {
    Role = "Developer-ReadOnly"
  }
}

# 2. Attach the AWS Managed Policy: ReadOnlyAccess
resource "aws_iam_user_policy_attachment" "read_only" {
  user       = aws_iam_user.developer.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# 3. Inline Policy allowing the user to upload files to our assets bucket (For grading requirements)
resource "aws_iam_user_policy" "s3_upload" {
  name = "bedrock-dev-s3-upload-policy"
  user = aws_iam_user.developer.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "arn:aws:aws:s3:::bedrock-assets-${var.student_id}/*"
      }
    ]
  })
}

# 4. Generate access keys to supply in our final grading deliverables
resource "aws_iam_access_key" "developer_keys" {
  user = aws_iam_user.developer.name
}
