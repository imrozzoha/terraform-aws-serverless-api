output "api_endpoint" {
  description = "Full HTTPS URL of the deployed API endpoint (e.g. https://<id>.execute-api.<region>.amazonaws.com/prod/<path>)."
  value       = "${aws_api_gateway_stage.this.invoke_url}/${var.api_path}"
}

output "api_id" {
  description = "The REST API ID."
  value       = aws_api_gateway_rest_api.this.id
}

output "api_execution_arn" {
  description = "The execution ARN of the REST API (used for Lambda permissions)."
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "lambda_function_name" {
  description = "The Lambda function name."
  value       = aws_lambda_function.this.function_name
}

output "lambda_function_arn" {
  description = "The Lambda function ARN."
  value       = aws_lambda_function.this.arn
}

output "lambda_role_arn" {
  description = "The ARN of the Lambda IAM execution role."
  value       = aws_iam_role.lambda.arn
}
