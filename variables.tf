variable "aws_region" {
  description = "Regiao AWS"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Profile AWS local (opcional)"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Prefixo de nome dos recursos"
  type        = string
  default     = "togglemaster"
}

variable "environment" {
  description = "Ambiente alvo"
  type        = string
  default     = "dev"
}

variable "tfstate_bucket_name" {
  description = "Nome globalmente unico do bucket S3 do backend Terraform"
  type        = string
}

variable "create_tfstate_bucket" {
  description = "Cria o bucket do backend. Use false para adotar um bucket ja existente."
  type        = bool
  default     = true
}

variable "create_github_oidc_provider" {
  description = "Se true, cria o provider OIDC do GitHub Actions"
  type        = bool
  default     = true
}

variable "github_oidc_provider_arn" {
  description = "ARN de um provider OIDC existente (usar se create_github_oidc_provider=false)"
  type        = string
  default     = ""
}

variable "create_iam_roles" {
  description = "Cria as roles do GitHub Actions. Use false para adotar roles ja existentes."
  type        = bool
  default     = true
}

variable "create_iam_policies" {
  description = "Cria as policies do GitHub Actions. Use false para adotar policies ja existentes."
  type        = bool
  default     = true
}

variable "github_owner" {
  description = "Owner dos repositorios no GitHub"
  type        = string
  default     = "jhouzera"
}

variable "lab_environment" {
  description = "Ambiente de laboratório único"
  type        = string
  default     = "dev"
}

variable "secrets_generator_github_repository" {
  description = "Repositorio autorizado a assumir a role do secrets-generator"
  type        = string
  default     = "togglemaster-secrets-generator"
}


# ---------------------------------------------------------------------------
# VPN de administracao (OpenVPN) — ver vpn.tf
# ---------------------------------------------------------------------------

variable "vpn_instance_type" {
  description = "Tipo da instancia da VPN (free tier)"
  type        = string
  default     = "t3.micro"
}

variable "vpn_vpc_cidr" {
  description = "CIDR da VPC dedicada da VPN (nao pode sobrepor a VPC da plataforma)"
  type        = string
  default     = "10.100.0.0/24"
}

variable "vpn_subnet_cidr" {
  description = "CIDR da subnet publica onde fica a instancia da VPN"
  type        = string
  default     = "10.100.0.0/26"
}

variable "vpn_availability_zone" {
  description = "AZ da subnet da VPN"
  type        = string
  default     = "us-east-1a"
}

variable "vpn_port" {
  description = "Porta UDP do OpenVPN"
  type        = number
  default     = 1194
}

variable "vpn_allowed_cidrs" {
  description = "Origens autorizadas a abrir o tunel. Precisa incluir os runners do GitHub Actions (IPs dinamicos)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vpn_client_cidr" {
  description = "Pool de enderecos entregue aos clientes da VPN (sai via NAT com o IP privado da instancia)"
  type        = string
  default     = "10.8.0.0/24"
}

variable "vpn_routed_cidrs" {
  description = "Redes empurradas para os clientes (split tunnel). Padrao: VPC da plataforma (togglemaster-iac)."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "vpn_clients" {
  description = "Perfis de cliente gerados. 'github-actions' e usado pelas pipelines do togglemaster-iac."
  type        = list(string)
  default     = ["admin", "github-actions"]
}
