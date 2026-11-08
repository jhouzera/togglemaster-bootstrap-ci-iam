# togglemaster-bootstrap-ci-iam

Módulo *Bootstrap* de IaC do projeto ToggleMaster.

## 🎯 Propósito
É o passo 0 para criar a "infraestrutura que cria infraestrutura". Ele provisiona o bucket S3 de state do Terraform, o provedor de identidade OIDC e as roles do GitHub Actions. A VPN de administração está desativada (`vpn.tf.disabled`).

## 🚀 Como Utilizar
Esta stack deve ser rodada manualmente apenas **uma vez** por conta AWS/ambiente, direto pelo computador de um administrador ou via console/CLI provisório, antes da construção geral do projeto.

```bash
terraform init
terraform apply
```

Uma vez aplicado, as pipelines GitHub Actions ganham o direito de "Assumir as Roles" e continuar orquestrando a infraestrutura a partir daí sem precisarem de chaves cadastradas estaticamente.
