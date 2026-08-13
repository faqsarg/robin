# Bootstrap: the `robin-terraform-deployer` IAM user

`robin-infra`'s Terraform Cloud workspace authenticates to AWS as an IAM user called
`robin-terraform-deployer`. Its permissions are **not managed by the Terraform in this repo** —
this file explains why, and documents exactly what it has.

## Why this isn't in the main Terraform code

Terraform Cloud needs AWS credentials to run `plan`/`apply` at all. If those credentials were
themselves defined by a resource in the same Terraform run, applying that run would require
credentials that don't exist yet — a circular dependency. This is a standard bootstrapping
problem: the identity that operates Terraform has to be created once, by hand, outside of it.

## What was actually run

```bash
# 1. Create the scoped policy (see deployer-policy.json for the current, exact content)
aws iam create-policy \
  --policy-name robin-terraform-deployer-policy \
  --policy-document file://deployer-policy.json \
  --tags Key=Project,Value=robin-devops-challenge

# 2. Create a dedicated IAM user - never reuse a personal admin account for automation
aws iam create-user --user-name robin-terraform-deployer \
  --tags Key=Project,Value=robin-devops-challenge Key=Purpose,Value=terraform-cloud-deployer

# 3. Attach the policy
aws iam attach-user-policy \
  --user-name robin-terraform-deployer \
  --policy-arn arn:aws:iam::915170001562:policy/robin-terraform-deployer-policy

# 4. Generate access keys and push them straight into the TFC workspace as sensitive
#    env vars (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY) - they were never written to
#    disk or shown in a terminal, only piped directly into the TFC API.
aws iam create-access-key --user-name robin-terraform-deployer
```

No `AdministratorAccess`, no reused personal credentials - a scoped policy for exactly the
services this project provisions (EC2/VPC, ECR, ECS, RDS, ELB, CloudWatch Logs, Secrets Manager),
plus IAM permissions limited to resources named `robin-*`.

## Why it grew after the initial setup

The policy started narrower and was widened three times as Terraform hit real `AccessDenied`
errors for things the initial scope didn't anticipate - each one found by actually running
`terraform apply`, not predicted in advance:

1. `iam:GetOpenIDConnectProvider` / `iam:ListOpenIDConnectProviders` - needed once
   `infra/github_oidc.tf` started reading the account's existing GitHub OIDC provider.
2. `iam:UpdateAssumeRolePolicy` - needed to update the CI/CD role's trust policy when fixing the
   GitHub immutable-subject-claim issue (see the main README's "Where AI got something wrong").

`deployer-policy.json` in this folder is kept in sync with whatever is actually applied in AWS -
if they ever drift, AWS is the source of truth (this file documents it, Terraform doesn't
enforce it).

## What I'd do differently with more time

Manage this with a **separate Terraform Cloud workspace and state**, applied once using
the account owner's own AWS credentials, so this policy would be fully version-controlled and
diffable like everything else - instead of an IAM user/policy applied by hand and only mirrored
here as documentation. Skipped for this challenge to avoid a second TFC workspace for a
one-time setup.
