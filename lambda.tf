# lambda.tf
# Three things defined here:
#   1. IAM role — the identity Lambda assumes when it runs
#   2. IAM policy — exact DynamoDB permissions granted to that role
#   3. Two Lambda functions — create_short_url and redirect_url

# ── IAM Role ──────────────────────────────────────────────────────────────────
# Every Lambda needs a role. Think of it as the Lambda's employee badge.
# The assume_role_policy says: "Lambda service is allowed to wear this badge"
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ── IAM Policy ────────────────────────────────────────────────────────────────
# Principle of least privilege: Lambda gets ONLY the DynamoDB actions it needs.
# GetItem  = redirect_url reads one item
# PutItem  = create_short_url writes one item
# No DeleteItem, no Scan, no admin actions — intentionally excluded
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${var.project_name}-lambda-dynamodb-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",  # used by redirect_url
        "dynamodb:PutItem",  # used by create_short_url
      ]
      # Scope permission to ONLY this specific table — not all DynamoDB tables
      Resource = aws_dynamodb_table.url_shortener.arn
    }]
  })
}

# Attach AWS managed policy for basic Lambda logging to CloudWatch
# Without this, Lambda can't write logs — debugging becomes impossible
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ── Package the Python code into ZIP files ────────────────────────────────────
# Lambda expects a ZIP archive — Terraform's archive_file does this automatically
# Each function gets its own ZIP so they deploy independently

data "archive_file" "create_short_url" {
  type        = "zip"
  source_file = "${path.module}/lambda/create_short_url.py"
  output_path = "${path.module}/lambda/create_short_url.zip"
}

data "archive_file" "redirect_url" {
  type        = "zip"
  source_file = "${path.module}/lambda/redirect_url.py"
  output_path = "${path.module}/lambda/redirect_url.zip"
}

# ── Lambda Function 1: create_short_url ───────────────────────────────────────
resource "aws_lambda_function" "create_short_url" {
  function_name    = "${var.project_name}-create-short-url"
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "python3.12"
  handler          = "create_short_url.lambda_handler" # filename.function_name
  filename         = data.archive_file.create_short_url.output_path
  source_code_hash = data.archive_file.create_short_url.output_base64sha256
  # source_code_hash: Terraform re-deploys the function ONLY when the ZIP content
  # actually changes — prevents unnecessary deploys on unrelated terraform applies

  timeout     = 10   # seconds — more than enough for a DynamoDB write
  memory_size = 128  # MB — minimum, sufficient for this workload, cheapest option

  environment {
    variables = {
      # TABLE_NAME read by: table = dynamodb.Table(os.environ["TABLE_NAME"])
      TABLE_NAME = aws_dynamodb_table.url_shortener.name
      # BASE_URL is a placeholder for now — we'll update this in Milestone 3
      # after API Gateway is created and we have the real invoke URL
      BASE_URL   = aws_apigatewayv2_stage.default.invoke_url

    }
  }
}

# ── Lambda Function 2: redirect_url ───────────────────────────────────────────
resource "aws_lambda_function" "redirect_url" {
  function_name    = "${var.project_name}-redirect-url"
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "python3.12"
  handler          = "redirect_url.lambda_handler"
  filename         = data.archive_file.redirect_url.output_path
  source_code_hash = data.archive_file.redirect_url.output_base64sha256

  timeout     = 10
  memory_size = 128

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.url_shortener.name
    }
  }
}
