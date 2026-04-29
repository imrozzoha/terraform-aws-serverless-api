# ---------------------------------------------------------------------------
# Naming
# ---------------------------------------------------------------------------

variable "name" {
  description = "Name prefix applied to all resources created by this module."
  type        = string
}

# ---------------------------------------------------------------------------
# Lambda
# ---------------------------------------------------------------------------

variable "lambda_zip_path" {
  description = "Path to the Lambda deployment package (.zip)."
  type        = string
}

variable "lambda_handler" {
  description = "Lambda handler in the format <module>.<function> (e.g. handler.lambda_handler)."
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda runtime identifier."
  type        = string
  default     = "python3.12"
}

variable "lambda_memory_size" {
  description = "Amount of memory in MB allocated to the Lambda function."
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds."
  type        = number
  default     = 30
}

variable "lambda_environment_variables" {
  description = "Map of environment variables to pass to the Lambda function."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# IAM — additional permissions
# ---------------------------------------------------------------------------

variable "enable_ses_send" {
  description = "Grant the Lambda role ses:SendEmail and ses:SendRawEmail permissions. Enable for contact-form use cases."
  type        = bool
  default     = false
}

variable "additional_iam_statements" {
  description = <<-EOT
    Additional IAM policy statements to attach to the Lambda execution role.
    Each object must have Effect, Action (list), and Resource (list).
  EOT
  type = list(object({
    Effect   = string
    Action   = list(string)
    Resource = list(string)
  }))
  default = []
}

# ---------------------------------------------------------------------------
# API Gateway
# ---------------------------------------------------------------------------

variable "api_path" {
  description = "The URL path segment for the API resource (e.g. \"contact\" creates POST /contact)."
  type        = string
}

variable "cors_allowed_origin" {
  description = "Value of the Access-Control-Allow-Origin header. Use \"*\" for public APIs or a specific origin for production."
  type        = string
  default     = "*"
}

variable "throttling_rate_limit" {
  description = "API Gateway steady-state requests per second."
  type        = number
  default     = 5
}

variable "throttling_burst_limit" {
  description = "API Gateway burst request limit."
  type        = number
  default     = 20
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
