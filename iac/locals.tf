# ---------------------------------------------------------------------------
# Valores locales compartidos.
# ---------------------------------------------------------------------------

locals {
  name_prefix = var.project

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
