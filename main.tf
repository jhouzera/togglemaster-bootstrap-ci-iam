data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "tls_certificate" "github_oidc" {
  count = var.create_github_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_oidc[0].certificates[0].sha1_fingerprint]
}

locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
  lab_environments         = { (var.lab_environment) = true }

  # GitHub inclui os IDs imutaveis de owner/repo no claim sub (repo:owner@id/repo@id:...); usar wildcard para casar com StringLike.
  iac_subs = {
    for env in keys(local.lab_environments) :
    env => [
      "repo:${var.github_owner}@*/togglemaster-iac@*:environment:${env}"
    ]
  }

  ecr_subs = {
    for env in keys(local.lab_environments) :
    env => [
      "repo:${var.github_owner}@*/togglemaster-apps@*:environment:${env}"
    ]
  }

  ecr_repo_arns = [
    for env in keys(local.lab_environments) :
    "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}-${env}/*"
  ]

  secrets_generator_subs = {
    for env in keys(local.lab_environments) :
    env => [
      "repo:${var.github_owner}@*/${var.secrets_generator_github_repository}@*:environment:${env}",
      "repo:${var.github_owner}@*/${var.secrets_generator_github_repository}@*:pull_request"
    ]
  }

  secrets_manager_arns = {
    for env in keys(local.lab_environments) :
    env => "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${env}/*"
  }
}

data "aws_s3_bucket" "tfstate" {
  count  = var.create_tfstate_bucket ? 0 : 1
  bucket = var.tfstate_bucket_name
}

data "aws_iam_role" "iac" {
  for_each = var.create_iam_roles ? {} : local.lab_environments
  name     = "${var.project_name}-${each.key}-github-actions-iac-role"
}

data "aws_iam_role" "ecr" {
  for_each = var.create_iam_roles ? {} : local.lab_environments
  name     = "${var.project_name}-${each.key}-github-actions-ecr-role"
}

data "aws_iam_role" "secrets_generator" {
  for_each = var.create_iam_roles ? {} : local.lab_environments
  name     = "${var.project_name}-${each.key}-github-actions-secrets-generator-role"
}

data "aws_iam_policy" "iac" {
  for_each = var.create_iam_policies ? {} : local.lab_environments
  name     = "${var.project_name}-${each.key}-github-actions-iac-policy"
}

data "aws_iam_policy" "ecr" {
  for_each = var.create_iam_policies ? {} : local.lab_environments
  name     = "${var.project_name}-${each.key}-github-actions-ecr-policy"
}

data "aws_iam_policy" "secrets_generator" {
  for_each = var.create_iam_policies ? {} : local.lab_environments
  name     = "${var.project_name}-${each.key}-github-actions-secrets-generator-policy"
}

locals {
  tfstate_bucket_id  = var.create_tfstate_bucket ? aws_s3_bucket.tfstate[0].id : data.aws_s3_bucket.tfstate[0].id
  tfstate_bucket_arn = var.create_tfstate_bucket ? aws_s3_bucket.tfstate[0].arn : data.aws_s3_bucket.tfstate[0].arn
  iac_role_names     = { for env in keys(local.lab_environments) : env => var.create_iam_roles ? aws_iam_role.iac[env].name : data.aws_iam_role.iac[env].name }
  ecr_role_names     = { for env in keys(local.lab_environments) : env => var.create_iam_roles ? aws_iam_role.ecr[env].name : data.aws_iam_role.ecr[env].name }
  secrets_generator_role_names = {
    for env in keys(local.lab_environments) : env => var.create_iam_roles ? aws_iam_role.secrets_generator[env].name : data.aws_iam_role.secrets_generator[env].name
  }
  iac_policy_arns = { for env in keys(local.lab_environments) : env => var.create_iam_policies ? aws_iam_policy.iac[env].arn : data.aws_iam_policy.iac[env].arn }
  ecr_policy_arns = { for env in keys(local.lab_environments) : env => var.create_iam_policies ? aws_iam_policy.ecr[env].arn : data.aws_iam_policy.ecr[env].arn }
  secrets_generator_policy_arns = {
    for env in keys(local.lab_environments) : env => var.create_iam_policies ? aws_iam_policy.secrets_generator[env].arn : data.aws_iam_policy.secrets_generator[env].arn
  }
}

resource "aws_s3_bucket" "tfstate" {
  count  = var.create_tfstate_bucket ? 1 : 0
  bucket = var.tfstate_bucket_name

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "terraform-backend"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = local.tfstate_bucket_id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = local.tfstate_bucket_id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = local.tfstate_bucket_id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "tfstate_tls" {
  bucket = local.tfstate_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          local.tfstate_bucket_arn,
          "${local.tfstate_bucket_arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "iac" {
  for_each = var.create_iam_roles ? local.lab_environments : {}

  name = "${var.project_name}-${each.key}-github-actions-iac-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.iac_subs[each.key]
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "iac" {
  for_each = var.create_iam_policies ? local.lab_environments : {}

  name        = "${var.project_name}-${each.key}-github-actions-iac-policy"
  description = "Permissoes para pipeline Terraform do ToggleMaster (${each.key})"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "eks:*",
          "iam:*",
          "rds:*",
          "elasticache:*",
          "dynamodb:*",
          "ecr:*",
          "sqs:*",
          "secretsmanager:*",
          "cloudwatch:*",
          "autoscaling:*",
          "kms:*",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketPolicy",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock"
        ]
        Resource = local.tfstate_bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${local.tfstate_bucket_arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "iac" {
  for_each = local.lab_environments

  role       = local.iac_role_names[each.key]
  policy_arn = local.iac_policy_arns[each.key]
}

# Migracao do recurso unico (ambiente "dev") para o for_each por ambiente, sem destruir/recriar a role existente.
moved {
  from = aws_iam_role.iac
  to   = aws_iam_role.iac["dev"]
}

moved {
  from = aws_iam_policy.iac
  to   = aws_iam_policy.iac["dev"]
}

moved {
  from = aws_iam_role_policy_attachment.iac
  to   = aws_iam_role_policy_attachment.iac["dev"]
}

resource "aws_iam_role" "ecr" {
  for_each = var.create_iam_roles ? local.lab_environments : {}

  name = "${var.project_name}-${each.key}-github-actions-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.ecr_subs[each.key]
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecr" {
  for_each    = var.create_iam_policies ? local.lab_environments : {}
  name        = "${var.project_name}-${each.key}-github-actions-ecr-policy"
  description = "Permissoes para build e push de imagens no ECR (${each.key})"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:ListImages",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = local.ecr_repo_arns[index(keys(local.lab_environments), each.key)]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr" {
  for_each = local.lab_environments

  role       = local.ecr_role_names[each.key]
  policy_arn = local.ecr_policy_arns[each.key]
}

# Migracao do recurso unico (ambiente "dev") para o for_each por ambiente, sem destruir/recriar a role existente.
moved {
  from = aws_iam_role.ecr
  to   = aws_iam_role.ecr["dev"]
}

moved {
  from = aws_iam_policy.ecr
  to   = aws_iam_policy.ecr["dev"]
}

moved {
  from = aws_iam_role_policy_attachment.ecr
  to   = aws_iam_role_policy_attachment.ecr["dev"]
}


resource "aws_iam_role" "secrets_generator" {
  for_each = var.create_iam_roles ? local.lab_environments : {}

  name = "${var.project_name}-${each.key}-github-actions-secrets-generator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.secrets_generator_subs[each.key]
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "secrets_generator" {
  for_each = var.create_iam_policies ? local.lab_environments : {}

  name        = "${var.project_name}-${each.key}-github-actions-secrets-generator-policy"
  description = "Permissoes para o workflow secrets-generator criar/atualizar secrets no Secrets Manager (${each.key})"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:TagResource"
        ]
        Resource = local.secrets_manager_arns[each.key]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_generator" {
  for_each = local.lab_environments

  role       = local.secrets_generator_role_names[each.key]
  policy_arn = local.secrets_generator_policy_arns[each.key]
}

# Migracao do recurso unico (ambiente "dev") para o for_each por ambiente, sem destruir/recriar a role existente.
moved {
  from = aws_iam_role.secrets_generator
  to   = aws_iam_role.secrets_generator["dev"]
}

moved {
  from = aws_iam_policy.secrets_generator
  to   = aws_iam_policy.secrets_generator["dev"]
}

moved {
  from = aws_iam_role_policy_attachment.secrets_generator
  to   = aws_iam_role_policy_attachment.secrets_generator["dev"]
}

