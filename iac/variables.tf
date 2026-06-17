# ---------------------------------------------------------------------------
# Variables globales del proyecto.
# Las variables específicas de cada capa (RDS, Redis, ECS, etc.) se declaran
# junto a sus recursos correspondientes.
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "Región AWS donde se despliega la plataforma"
  type        = string
  default     = "us-east-2"
}

variable "project" {
  description = "Nombre corto del proyecto, usado como prefijo de los recursos"
  type        = string
  default     = "pepito-pan"
}

variable "environment" {
  description = "Ambiente de despliegue (localhost | dev)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["localhost", "dev"], var.environment)
    error_message = "El ambiente debe ser 'localhost' o 'dev'."
  }
}

variable "vpc_cidr" {
  description = "Bloque CIDR principal de la VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "azs" {
  description = "Zonas de disponibilidad (3 AZ para los picos de fin de semana)"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs de las subredes públicas (ALB y NAT Gateway)"
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs de las subredes privadas (ECS, RDS, Redis)"
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24", "10.20.12.0/24"]
}
