terraform {
  backend "s3" {
    bucket         = "com.leaptalk.terraform.state"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "lt-demo-terrform-state-lock-table"
  }
}
