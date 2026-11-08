output "tfstate_bucket_name" {
  description = "Nome do bucket S3 para state remoto"
  value       = local.tfstate_bucket_id
}

output "iac_role_arns" {
  description = "ARNs das roles usadas pela pipeline de IaC, por ambiente"
  value       = { for env in keys(local.lab_environments) : env => var.create_iam_roles ? aws_iam_role.iac[env].arn : data.aws_iam_role.iac[env].arn }
}

output "ecr_role_arns" {
  description = "ARNs das roles usadas pela pipeline de build/push no ECR, por ambiente"
  value       = { for env in keys(local.lab_environments) : env => var.create_iam_roles ? aws_iam_role.ecr[env].arn : data.aws_iam_role.ecr[env].arn }
}

output "secrets_generator_role_arns" {
  description = "ARNs das roles usadas pelo workflow secrets-generator, por ambiente"
  value       = { for env in keys(local.lab_environments) : env => var.create_iam_roles ? aws_iam_role.secrets_generator[env].arn : data.aws_iam_role.secrets_generator[env].arn }
}

output "github_oidc_provider_arn" {
  description = "ARN do provider OIDC do GitHub Actions"
  value       = local.github_oidc_provider_arn
}
