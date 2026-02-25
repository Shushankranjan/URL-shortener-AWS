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
