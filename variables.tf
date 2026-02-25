# variables.tf
# Single source of truth for all configurable values.
# Change here → changes everywhere. No hunting through files.

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix applied to every resource name — makes console navigation easy"
  type        = string
  default     = "url-shortener"
}

variable "test_user_email" {
  description = "Email for the auto-created Cognito test user"
  type        = string
  default     = "testuser@example.com" # change to any email you want
}

variable "test_user_password" {
  description = "Temporary password for the test user — Cognito will ask to change it on first login"
  type        = string
  default     = "TempPass123!" # must have uppercase, lowercase, number, special char
  sensitive   = true           # sensitive = true: Terraform never prints this in logs
}
