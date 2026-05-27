
terraform {
  backend "s3" {
    bucket       = "bedrock-tf-state-alt-soe-025-4423"
    key          = "stage/bedrock-infra/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
