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

# GitHub's OIDC tokens for any repo created after 2026-07-15 use immutable
# subject claims (repo:OWNER@OWNER-ID/REPO@REPO-ID:...) instead of plain
# names, so a recycled username/repo name can't inherit an old trust policy.
# IDs confirmed via: curl https://api.github.com/repos/faqsarg/robin
variable "github_owner_id" {
  description = "Immutable GitHub owner ID, required for the OIDC sub claim"
  type        = string
  default     = "88861034"
}

variable "github_repo_id" {
  description = "Immutable GitHub repository ID, required for the OIDC sub claim"
  type        = string
  default     = "1333167007"
}
