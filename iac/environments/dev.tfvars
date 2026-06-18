# ===========================================================================
# Ambiente: dev (desarrollo)
#
# Puertos expuestos (5001-5005):
#   5001 -> frontend (nginx)
#   5002 -> backend (Node.js)
#   5003 -> postgres
#   5004 -> redis
#   5005 -> lambda (simulada vía HTTP en desarrollo)
# ===========================================================================

environment = "dev"
project     = "pepito-pan"
aws_region  = "us-east-2"

# Completar con el dominio y el correo del administrador cuando estén disponibles.
domain_name = ""
admin_email = ""
