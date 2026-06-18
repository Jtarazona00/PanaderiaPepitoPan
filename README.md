# Plataforma de Pedidos Online — Infraestructura (Terraform)

Infraestructura como código (IaC) en **Terraform** para la plataforma web
transaccional de pedidos en local de una cadena de restaurantes con **350 sedes**
bajo una misma marca y menú unificado.

La plataforma atiende clientes web, al personal de las 350 sedes y a
administradores. Opera de **martes a domingo de 9:00 a 21:00**, con una
concurrencia diaria promedio de **14 000 usuarios**, picos de **25 600** en
horario crítico y hasta **35 000** los fines de semana.

> No hay delivery: el sistema gestiona únicamente pedidos en local. El menú es
> idéntico para las 350 sedes, pero la disponibilidad de platos varía por sede
> en tiempo real según el inventario de cada local.

## Región y zonas

- Región: **us-east-2**
- Zonas de disponibilidad: **us-east-2a**, **us-east-2b**, **us-east-2c**
  (la 3.ª AZ se usa para escalar en los picos de fin de semana).

## Componentes principales

| Capa | Servicios AWS |
|------|---------------|
| Borde / CDN | Route 53 → CloudFront → API Gateway HTTP v2 → ALB (WAF v2) |
| Cómputo | ECS Fargate (frontend nginx + backend Node.js) en 3 AZ |
| Datos | RDS PostgreSQL 16 Multi-AZ + réplica de lectura · ElastiCache Redis |
| Asíncrono | Lambda + SQS (+ DLQ) + SNS/SES para manejo de errores y alertas |
| Seguridad | KMS (cifrado transversal), IAM, WAF v2, SSM Parameter Store |
| Operación | CloudWatch (dashboard + alarmas), AWS Backup, ECR |

## Estructura del repositorio

```
iac/                       Código Terraform
  versions.tf              Versiones de Terraform y providers
  providers.tf             Provider AWS y etiquetas por defecto
  variables.tf             Variables globales
  locals.tf                Valores locales compartidos
  outputs.tf               Salidas (endpoints, URLs de ECR, ARNs)
  vpc.tf                   Red: VPC, subredes 3 AZ, NAT, rutas
  kms.tf                   Cifrado transversal (KMS)
  iam.tf                   Grupos y roles (IAM)
  security_groups.tf       Security groups por capa
  waf.tf                   WAF v2 (OWASP + SQLi + rate limit)
  ssm.tf                   Credenciales DB (SecureString)
  s3_logs.tf               Bucket de logs de acceso
  rds.tf                   PostgreSQL 16 Multi-AZ + réplica
  elasticache.tf           Redis (caché de lectura)
  ecr.tf                   Repositorios de imágenes
  alb.tf                   ALB + target groups + listeners
  ecs.tf                   ECS Fargate + autoscaling
  cloudfront.tf            CDN
  apigateway.tf            API Gateway HTTP v2 + VPC Link
  route53.tf               DNS
  sqs.tf                   Cola + DLQ
  lambda.tf                Manejo de errores
  sns.tf                   Alertas
  cloudwatch.tf            Dashboard y alarmas
  backup.tf                AWS Backup
  environments/
    localhost.tfvars       Ambiente local (puertos 4001-4005)
    dev.tfvars             Ambiente dev (puertos 5001-5005)
docs/
  ARQUITECTURA.md          Flujo y mapeo de los RNF
```

## Cómo usar

```bash
cd iac
terraform init
terraform plan  -var="environment=dev"
terraform apply -var="environment=dev"
```

## Análisis de seguridad estático (Checkov)

```bash
docker pull bridgecrew/checkov:3
docker run --rm -v ./iac:/tf --workdir /tf bridgecrew/checkov:3 \
  --directory /tf -o junitxml --output-file-path results.xml
```

## Ambientes

- **localhost** — simulación local (puertos 4001-4005). Lambda simulada vía HTTP en el puerto 4005.
- **dev** — entorno de desarrollo (puertos 5001-5005). Lambda simulada vía HTTP en el puerto 5005.
