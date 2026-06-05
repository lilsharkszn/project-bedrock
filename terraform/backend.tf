
terraform {
  backend "s3" {
    bucket       = "bedrock-tf-state-225201316405"
    key          = "stage/bedrock-infra/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
