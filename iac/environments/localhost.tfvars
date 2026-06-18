# ===========================================================================
# Ambiente: localhost (simulación local, p. ej. LocalStack)
#
# Puertos expuestos (4001-4005):
#   4001 -> frontend (nginx)
#   4002 -> backend (Node.js)
#   4003 -> postgres
#   4004 -> redis
#   4005 -> lambda (simulada vía HTTP, sin necesitar AWS real)
# ===========================================================================

environment = "localhost"
project     = "pepito-pan"
aws_region  = "us-east-2"

# En local no se usan dominio ni correo reales.
domain_name = ""
admin_email = ""
