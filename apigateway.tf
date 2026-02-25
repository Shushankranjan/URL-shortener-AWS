# apigateway.tf
# Builds an HTTP API with two routes wired to your Lambda functions.
#
# Resource chain:
#   aws_apigatewayv2_api          → the API itself (the building)
#   aws_apigatewayv2_integration  → connects API to Lambda (the hallway)
#   aws_apigatewayv2_route        → maps a URL path to an integration (the door)
#   aws_apigatewayv2_stage        → deploys the API to a live URL (the "open for business" sign)
#   aws_lambda_permission         → allows API Gateway to invoke Lambda (the keycard)

# ── The API ───────────────────────────────────────────────────────────────────
resource "aws_apigatewayv2_api" "url_shortener" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP" # HTTP API — cheaper and faster than REST API

  # CORS configuration: allows browsers to call this API from any origin
  # In production you'd replace "*" with your actual frontend domain
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
  }
}

# ── Integration 1: API Gateway → create_short_url Lambda ─────────────────────
resource "aws_apigatewayv2_integration" "create_short_url" {
  api_id             = aws_apigatewayv2_api.url_shortener.id
  integration_type   = "AWS_PROXY" # Proxy mode: passes the full request to Lambda as-is
                                   # Lambda receives the raw event and controls the full response
  integration_uri    = aws_lambda_function.create_short_url.invoke_arn
  integration_method = "POST" # API Gateway always uses POST when calling Lambda internally
}

# ── Integration 2: API Gateway → redirect_url Lambda ─────────────────────────
resource "aws_apigatewayv2_integration" "redirect_url" {
  api_id             = aws_apigatewayv2_api.url_shortener.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.redirect_url.invoke_arn
  integration_method = "POST"
}

# ── Route 1: POST /shorten ────────────────────────────────────────────────────
resource "aws_apigatewayv2_route" "create_short_url" {
  api_id    = aws_apigatewayv2_api.url_shortener.id
  route_key = "POST /shorten"
  target    = "integrations/${aws_apigatewayv2_integration.create_short_url.id}"

  # Wire the Cognito authorizer to this route
  # JWT = use the JWT authorizer we defined in cognito.tf
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# ── Route 2: GET /{short_code} ────────────────────────────────────────────────
resource "aws_apigatewayv2_route" "redirect_url" {
  api_id    = aws_apigatewayv2_api.url_shortener.id
  route_key = "GET /{short_code}" # {short_code} is a path parameter
                                  # API Gateway extracts it and puts it in event["pathParameters"]
  target    = "integrations/${aws_apigatewayv2_integration.redirect_url.id}"
}

# ── Stage: $default ───────────────────────────────────────────────────────────
# A stage is a named version of your API deployment (like dev/staging/prod)
# "$default" is a special stage that serves requests at the root URL
# without a stage prefix — so your URL is /shorten not /prod/shorten
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.url_shortener.id
  name        = "$default"
  auto_deploy = true # automatically deploys any route/integration changes
                     # removes the need to manually trigger a deployment
}

# ── Lambda Permission 1: allow API Gateway to invoke create_short_url ─────────
# Without this, API Gateway gets a 403 when trying to call Lambda
# Think of it as adding API Gateway to Lambda's allowed-callers list
resource "aws_lambda_permission" "create_short_url" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_short_url.function_name
  principal     = "apigateway.amazonaws.com"
  # source_arn restricts which specific API can invoke this Lambda
  # Without it, ANY API Gateway in your account could call this function
  source_arn    = "${aws_apigatewayv2_api.url_shortener.execution_arn}/*/*"
}

# ── Lambda Permission 2: allow API Gateway to invoke redirect_url ─────────────
resource "aws_lambda_permission" "redirect_url" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.redirect_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.url_shortener.execution_arn}/*/*"
}
