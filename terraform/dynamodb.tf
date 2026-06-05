resource "aws_dynamodb_table" "carts" {
  name         = "items"           # Matches the default table target name for the retail-store-sample-app carts service
  billing_mode = "PAY_PER_REQUEST" # On-demand pricing ensures we only pay for active hits, minimizing idle costs
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "project-bedrock-carts-dynamodb"
    Project = "karatu-2025-capstone"  
  }
}
