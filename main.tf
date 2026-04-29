# ---------------------------------------------------------------------------
# Lambda IAM role
# ---------------------------------------------------------------------------

resource "aws_iam_role" "lambda" {
  name = "${var.name}-lambda"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

locals {
  ses_statement = var.enable_ses_send ? [{
    Effect   = "Allow"
    Action   = ["ses:SendEmail", "ses:SendRawEmail"]
    Resource = ["*"]
  }] : []

  all_statements = concat(local.ses_statement, var.additional_iam_statements)
}

resource "aws_iam_role_policy" "lambda_extra" {
  count = length(local.all_statements) > 0 ? 1 : 0

  name = "${var.name}-extra"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.all_statements
  })
}

# ---------------------------------------------------------------------------
# Lambda function
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "this" {
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  function_name    = var.name
  role             = aws_iam_role.lambda.arn
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout
  tags             = var.tags

  dynamic "environment" {
    for_each = length(var.lambda_environment_variables) > 0 ? [1] : []
    content {
      variables = var.lambda_environment_variables
    }
  }
}

# ---------------------------------------------------------------------------
# API Gateway REST API
# ---------------------------------------------------------------------------

resource "aws_api_gateway_rest_api" "this" {
  name = var.name
  tags = var.tags
}

resource "aws_api_gateway_resource" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = var.api_path
}

# POST → Lambda proxy
resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.this.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.this.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.this.invoke_arn
}

# OPTIONS → MOCK (CORS preflight — no Lambda invocation)
resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.this.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this.id
  http_method = aws_api_gateway_method.options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = aws_api_gateway_method_response.options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${var.cors_allowed_origin}'"
  }

  depends_on = [aws_api_gateway_integration.options]
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# ---------------------------------------------------------------------------
# Deployment & stage
# ---------------------------------------------------------------------------

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.this.id,
      aws_api_gateway_method.post.id,
      aws_api_gateway_integration.post.id,
      aws_api_gateway_method.options.id,
      aws_api_gateway_integration.options.id,
      aws_api_gateway_integration_response.options.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.post,
    aws_api_gateway_integration_response.options,
  ]
}

resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = "prod"
  tags          = var.tags
}

resource "aws_api_gateway_method_settings" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
    logging_level          = "OFF"
    data_trace_enabled     = false
    metrics_enabled        = false
  }
}
