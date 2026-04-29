terraform {
  required_version = ">= 1.6"
  required_providers {
    aws  = { source = "hashicorp/aws", version = ">= 5.0" }
    null = { source = "hashicorp/null", version = ">= 3.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ---------------------------------------------------------------------------
# Package the Lambda function
# ---------------------------------------------------------------------------

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda.zip"
}

# ---------------------------------------------------------------------------
# Minimal public API endpoint
# ---------------------------------------------------------------------------

module "api" {
  source = "../../"

  name            = "my-hello-api"
  lambda_zip_path = data.archive_file.lambda.output_path
  lambda_handler  = "handler.lambda_handler"
  api_path        = "hello"

  cors_allowed_origin = "*"

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

output "api_endpoint" {
  value = module.api.api_endpoint
}
