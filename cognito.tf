# cognito.tf
# Three resources:
#   1. User Pool       — the database of users (stores emails, hashed passwords)
#   2. User Pool Client — the "app" that's allowed to authenticate against the pool
#   3. Test User       — a pre-created user so you can test immediately

# ── User Pool ─────────────────────────────────────────────────────────────────
# The User Pool is Cognito's user database.
# Think of it as the bouncer's master guest list.
resource "aws_cognito_user_pool" "url_shortener" {
  name = "${var.project_name}-user-pool"

  # Users log in with their email address, not a username
  username_attributes = ["email"]

  # Automatically verify email addresses by sending a confirmation code
  auto_verified_attributes = ["email"]

  # Password policy — Cognito enforces this on every signup/password change
  password_policy {
    minimum_length                   = 8
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7  # test user must change password within 7 days
  }

  # Schema defines what attributes users have
  # "email" is required — users cannot sign up without providing one
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }
}

# ── User Pool Client ──────────────────────────────────────────────────────────
# The App Client is the credential that allows YOUR application to talk to Cognito.
# Think of it as the ID card your app presents to Cognito when authenticating users.
# Without this, your API has no way to trigger the login flow.
resource "aws_cognito_user_pool_client" "url_shortener" {
  name         = "${var.project_name}-client"
  user_pool_id = aws_cognito_user_pool.url_shortener.id

  # No client secret — this is a public client (called from CLI/frontend directly)
  # Server-side apps would use generate_secret = true
  generate_secret = false

  # ALLOW_USER_PASSWORD_AUTH: email + password → JWT token exchange
  # ALLOW_REFRESH_TOKEN_AUTH: allows refreshing expired tokens without re-login
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # How long tokens stay valid:
  access_token_validity  = 1    # 1 hour — the token used to call your API
  refresh_token_validity = 30   # 30 days — used to get a new access token silently
  token_validity_units {
    access_token  = "hours"
    refresh_token = "days"
  }
}

# ── Test User ─────────────────────────────────────────────────────────────────
# Creates a real user in the pool so you can test the full login flow immediately.
# Terraform manages this user — it will be deleted with terraform destroy.
resource "aws_cognito_user" "test_user" {
  user_pool_id = aws_cognito_user_pool.url_shortener.id
  username     = var.test_user_email

  # Sets a temporary password — user must change it on first login
  temporary_password = var.test_user_password

  # Mark email as verified so the user doesn't need to go through
  # the email confirmation flow during testing
  attributes = {
    email          = var.test_user_email
    email_verified = "true"
  }

  # CONFIRMED = account is active and can log in immediately
  # Without this, the account sits in FORCE_CHANGE_PASSWORD state
  message_action = "SUPPRESS" # suppresses the welcome email Cognito would normally send
}

# ── API Gateway JWT Authorizer ────────────────────────────────────────────────
# This is the actual "bouncer" attached to API Gateway.
# When a request hits POST /shorten, API Gateway sends the Authorization header
# to this authorizer BEFORE invoking Lambda.
# If the JWT is valid → request proceeds. If not → 401 returned immediately.
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.url_shortener.id
  authorizer_type  = "JWT"
  name             = "${var.project_name}-cognito-authorizer"

  # Where API Gateway finds the JWT in the incoming request
  # "Authorization" header is the industry standard location for Bearer tokens
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    # audience = the App Client ID — Cognito checks that the token was issued FOR this app
    # A token from a different app will be rejected even if it's a valid Cognito token
    audience = [aws_cognito_user_pool_client.url_shortener.id]

    # issuer = the URL of your User Pool — proves the token came from YOUR Cognito pool
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.url_shortener.id}"
  }
}
