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
# Contact form API
# ---------------------------------------------------------------------------

module "contact_api" {
  source = "../../"

  name            = "my-app-contact"
  lambda_zip_path = data.archive_file.lambda.output_path
  lambda_handler  = "handler.lambda_handler"
  api_path        = "contact"

  # Grant Lambda permission to send email via SES
  enable_ses_send = true

  lambda_environment_variables = {
    RECIPIENT_EMAIL = "hello@example.com"
    SENDER_EMAIL    = "contact@example.com"
  }

  # Restrict CORS to your domain in production
  cors_allowed_origin = "https://example.com"

  throttling_rate_limit  = 5
  throttling_burst_limit = 10

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

output "contact_endpoint" {
  description = "POST to this URL to send a contact form submission."
  value       = module.contact_api.api_endpoint
}
