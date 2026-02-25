# outputs.tf
# Printed to terminal after apply. Also stored in state so
# Milestone 2 Terraform files can reference these values directly.

output "dynamodb_table_name" {
  description = "Used in Milestone 2 as Lambda environment variable TABLE_NAME"
  value       = aws_dynamodb_table.url_shortener.name
}

output "dynamodb_table_arn" {
  description = "Used in Milestone 2 when writing the IAM policy for Lambda"
  value       = aws_dynamodb_table.url_shortener.arn
}

output "create_short_url_function_name" {
  description = "Used in Milestone 3 to wire API Gateway to this function"
  value       = aws_lambda_function.create_short_url.function_name
}

output "redirect_url_function_name" {
  description = "Used in Milestone 3 to wire API Gateway to this function"
  value       = aws_lambda_function.redirect_url.function_name
}

output "api_url" {
  description = "The live HTTPS URL for your URL shortener API"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "cognito_user_pool_id" {
  description = "Needed to authenticate — used in the login command"
  value       = aws_cognito_user_pool.url_shortener.id
}

output "cognito_client_id" {
  description = "Needed to authenticate — used in the login command"
  value       = aws_cognito_user_pool_client.url_shortener.id
}

output "test_user_email" {
  description = "The test user's email"
  value       = var.test_user_email
}
