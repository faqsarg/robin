variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used to name and tag all resources"
  type        = string
  default     = "robin"
}

variable "github_repo" {
  description = "GitHub repo (owner/name) allowed to assume the CI/CD deploy role via OIDC"
  type        = string
  default     = "faqsarg/robin"
}
