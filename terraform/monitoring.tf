# =========================================
# SNS Topic
# =========================================
resource "aws_sns_topic" "alerts" {
  name = "project-bedrock-alerts"
}

# =========================================
# Email Subscription
# =========================================
resource "aws_sns_topic_subscription" "email_target" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "lilsharkszn@techie.com"
}

# =========================================
# CloudWatch Alarm
# =========================================
resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  alarm_name          = "high-cpu-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80

  alarm_description = "This metric monitors EC2 CPU utilization"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]
}

# =========================================
# Allow S3 to Publish to SNS
# =========================================
resource "aws_sns_topic_policy" "s3_to_sns" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "s3.amazonaws.com"
        }

        Action   = "SNS:Publish"
        Resource = aws_sns_topic.alerts.arn

        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::bedrock-assets-alt-soe-025-4423"
          }
        }
      }
    ]
  })
}

# =========================================
# S3 Bucket Notification
# =========================================
resource "aws_s3_bucket_notification" "assets_bucket_notification" {
  bucket = "bedrock-assets-alt-soe-025-4423"

  topic {
    topic_arn = aws_sns_topic.alerts.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_sns_topic_policy.s3_to_sns
  ]
}
