# Provider AWS. Las credenciales se toman del entorno / perfil configurado.
# Todos los recursos heredan las etiquetas por defecto definidas aquí.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

provider "random" {}
