# terraform-aws-serverless-api

A Terraform module that provisions a production-ready serverless API endpoint on AWS — API Gateway REST API + Lambda + IAM, with CORS, rate limiting, and optional SES email sending. Bring your own Lambda zip.

[![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.6-purple)](https://www.terraform.io/)
[![AWS Provider](https://img.shields.io/badge/aws-%3E%3D5.0-orange)](https://registry.terraform.io/providers/hashicorp/aws/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Features

- **API Gateway REST API** — single resource, POST + OPTIONS (CORS preflight)
- **Lambda proxy integration** — full request/response control in your handler
- **Least-privilege IAM** — Lambda execution role with CloudWatch Logs only, plus opt-in SES send permissions and custom policy statements
- **CORS** — configurable `Access-Control-Allow-Origin` header, MOCK-based preflight (no Lambda invocation cost)
- **Rate limiting** — configurable steady-state RPS and burst limit via API Gateway method settings
- **Bring your own zip** — module creates infrastructure; you provide the Lambda deployment package

---

## Architecture

```
Browser / client
      │  POST /<path>
      ▼
API Gateway REST API
  ├── OPTIONS /<path>  → MOCK integration (CORS preflight, zero cost)
  └── POST    /<path>  → AWS_PROXY → Lambda
        │  throttle: configurable RPS / burst
        ▼
Lambda function (your code)
  ├── IAM role: CloudWatch Logs (always)
  ├── IAM role: SES SendEmail (opt-in)
  └── IAM role: custom statements (opt-in)
        │
        ▼
{"statusCode": 200, "body": "..."}  →  API Gateway  →  client
```

---

## Usage

### Contact form (with SES)

```hcl
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda.zip"
}

module "contact_api" {
  source  = "imrozzoha/serverless-api/aws"
  version = "~> 1.0"

  name            = "my-app-contact"
  lambda_zip_path = data.archive_file.lambda.output_path
  lambda_handler  = "handler.lambda_handler"
  api_path        = "contact"

  enable_ses_send = true

  lambda_environment_variables = {
    RECIPIENT_EMAIL = "hello@example.com"
    SENDER_EMAIL    = "contact@example.com"
  }

  cors_allowed_origin    = "https://example.com"
  throttling_rate_limit  = 5
  throttling_burst_limit = 10

  tags = { Environment = "production" }
}

output "contact_url" { value = module.contact_api.api_endpoint }
```

### Minimal API endpoint

```hcl
module "api" {
  source  = "imrozzoha/serverless-api/aws"
  version = "~> 1.0"

  name            = "my-hello-api"
  lambda_zip_path = data.archive_file.lambda.output_path
  lambda_handler  = "handler.lambda_handler"
  api_path        = "hello"

  cors_allowed_origin = "*"
}
```

### With additional IAM permissions (e.g. DynamoDB)

```hcl
module "api" {
  source  = "imrozzoha/serverless-api/aws"
  version = "~> 1.0"

  name            = "my-dynamo-api"
  lambda_zip_path = data.archive_file.lambda.output_path
  lambda_handler  = "handler.lambda_handler"
  api_path        = "items"

  additional_iam_statements = [
    {
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem", "dynamodb:PutItem"]
      Resource = [aws_dynamodb_table.items.arn]
    }
  ]
}
```

---

## Examples

| Example | Description |
|---------|-------------|
| [contact-form](examples/contact-form/) | SES email sending — matches the portfolio contact form pattern |
| [api-endpoint](examples/api-endpoint/) | Minimal Hello World endpoint |

---

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

---

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `name` | Name prefix for all resources | `string` | — | yes |
| `lambda_zip_path` | Path to the Lambda .zip package | `string` | — | yes |
| `lambda_handler` | Handler in `module.function` format | `string` | — | yes |
| `api_path` | URL path segment (e.g. `"contact"` → POST `/contact`) | `string` | — | yes |
| `lambda_runtime` | Lambda runtime | `string` | `"python3.12"` | no |
| `lambda_memory_size` | Lambda memory in MB | `number` | `128` | no |
| `lambda_timeout` | Lambda timeout in seconds | `number` | `30` | no |
| `lambda_environment_variables` | Environment variables for Lambda | `map(string)` | `{}` | no |
| `enable_ses_send` | Grant `ses:SendEmail` + `ses:SendRawEmail` to Lambda role | `bool` | `false` | no |
| `additional_iam_statements` | Extra IAM policy statements for the Lambda role | `list(object)` | `[]` | no |
| `cors_allowed_origin` | `Access-Control-Allow-Origin` header value | `string` | `"*"` | no |
| `throttling_rate_limit` | Steady-state requests per second | `number` | `5` | no |
| `throttling_burst_limit` | Burst request limit | `number` | `20` | no |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |

### `additional_iam_statements` object

| Attribute | Type | Description |
|-----------|------|-------------|
| `Effect` | `string` | `"Allow"` or `"Deny"` |
| `Action` | `list(string)` | IAM actions (e.g. `["dynamodb:GetItem"]`) |
| `Resource` | `list(string)` | ARNs the actions apply to |

---

## Outputs

| Name | Description |
|------|-------------|
| `api_endpoint` | Full HTTPS URL — `https://<id>.execute-api.<region>.amazonaws.com/prod/<path>` |
| `api_id` | REST API ID |
| `api_execution_arn` | Execution ARN (for additional Lambda permissions) |
| `lambda_function_name` | Lambda function name |
| `lambda_function_arn` | Lambda function ARN |
| `lambda_role_arn` | Lambda IAM execution role ARN |

---

## Lambda handler contract

Your Lambda receives a standard API Gateway proxy event and must return a proxy response:

```python
def lambda_handler(event, context):
    # Handle CORS preflight
    if event.get('httpMethod') == 'OPTIONS':
        return {'statusCode': 200, 'headers': cors_headers(), 'body': ''}

    body = json.loads(event.get('body') or '{}')
    # ... your logic ...

    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',  # match cors_allowed_origin
        },
        'body': json.dumps({'result': 'ok'}),
    }
```

See [examples/contact-form/lambda/handler.py](examples/contact-form/lambda/handler.py) for a complete SES example.

---

## Real-world usage

This module is used in production by [imrozzoha.com](https://imrozzoha.com) — a personal portfolio site where:

- **`/contact`** — routes form submissions through SES to the site owner's email
- **`/chat`** — routes AI chat messages to a Bedrock-connected agent Lambda

Both endpoints share a single API Gateway with 5 rps / burst 20 throttling, IAM least-privilege roles, and CORS locked to the production domain.

---

## License

MIT — see [LICENSE](LICENSE).

---

## Author

**Imrozzoha Chowdhury** — Senior Staff DevSecOps & Platform Engineer
[imrozzoha.com](https://imrozzoha.com) · [LinkedIn](https://linkedin.com/in/imrozzoha)
