# Configuración vs. Provisionamiento

Análisis de qué cubre este proyecto en las dos grandes dimensiones de la
Infraestructura como Código (IaC): **provisionamiento** y **configuración**.

## Definiciones

- **Provisionamiento** — *crear y asignar* la infraestructura: red, cómputo,
  base de datos, almacenamiento, etc. Herramienta típica: **Terraform**.
- **Configuración (configuration management)** — *ajustar el software y el
  estado dentro* de esos recursos: paquetes, archivos de configuración,
  servicios, variables de la aplicación. Herramientas típicas: **Ansible,
  Chef, Puppet** (para servidores) o la **imagen del contenedor** (para
  arquitecturas contenedorizadas).

## 1. Provisionamiento — cubierto (completo)

Todo el stack se crea de forma declarativa con Terraform en `iac/`:

| Capa | Recursos provisionados |
|------|------------------------|
| Red | VPC, subredes en 3 AZ, NAT, IGW, tablas de rutas, VPC Flow Logs |
| Seguridad | KMS, IAM, security groups, WAF v2 |
| Datos | RDS PostgreSQL Multi-AZ + réplica de lectura, ElastiCache Redis |
| Cómputo | ECR, ALB, ECS/Fargate, Auto Scaling |
| Borde | CloudFront, API Gateway, Route 53 |
| Asíncrono / Observabilidad | SQS, Lambda, SNS, SES, CloudWatch, AWS Backup |

## 2. Configuración — cubierta (en su forma cloud-native)

No hay Ansible/Chef, pero sí existe **configuración**, en el estilo que exige
una arquitectura de contenedores + servicios gestionados:

| Tipo de configuración | Dónde, en el repo |
|-----------------------|-------------------|
| Config de **servicios gestionados** | `aws_db_parameter_group` (RDS), reglas del WAF, alarmas de CloudWatch, políticas de Auto Scaling y Scheduled Scaling (`iac/ecs.tf`) |
| **Config y secretos de la app** | SSM Parameter Store como SecureString (`iac/ssm.tf`) + bloques `environment` y `secrets` en las task definitions de ECS |
| **Config por ambiente** | `iac/environments/localhost.tfvars` y `dev.tfvars` (puertos 4001-4005 / 5001-5005) |
| **Config del entorno de herramientas** | `sonarqube/docker-compose.yml` |

## 3. Lo que no está en este repo (y por qué)

- **No hay Ansible/Chef/Puppet/cloud-init/`user_data`.** Y **no hacen falta**:
  no hay servidores ni instancias EC2 que configurar. La arquitectura es
  **Fargate + servicios gestionados**, donde ese rol lo cumplen la imagen del
  contenedor y la inyección de variables de entorno.
- **No están los Dockerfiles, el `nginx.conf`, el código del backend ni el ZIP
  de la Lambda.** Esa es la "configuración a nivel de software/imagen", y en
  este modelo **vive en los repositorios de la aplicación y se construye en el
  pipeline de CI** (por eso ECR se provisiona vacío y las imágenes se publican
  aparte). No es un vacío del IaC: es **separación de responsabilidades**.

## Veredicto

| Dimensión | Cobertura |
|-----------|-----------|
| Provisionamiento | ✅ Completo (Terraform declarativo de todo el stack) |
| Configuración de servicios gestionados | ✅ Sí (parameter groups, WAF, alarmas, autoscaling) |
| Configuración y secretos de la app | ✅ Sí (SSM SecureString + `environment` de ECS) |
| Configuración por ambiente | ✅ Sí (tfvars localhost / dev) |
| Config management clásico (Ansible/Chef) | ⛔ No aplica (arquitectura serverless/contenedores, sin servidores) |
| Config a nivel de imagen (Dockerfile/nginx.conf) | ⚠️ Fuera de este repo (pertenece al repo de la app + CI) |

**En una frase:** el proyecto **provisiona** toda la infraestructura y
**configura** lo que le corresponde a una arquitectura contenedorizada
(servicios gestionados + inyección de configuración/secretos por ambiente); lo
único de configuración que queda fuera —a propósito— es el contenido de las
imágenes de contenedor, que por diseño se maneja en el repositorio de la
aplicación y su pipeline.

> **Justificación de la ausencia de Ansible:** en Fargate/serverless no hay
> hosts que configurar, de modo que el *configuration management* se traslada a
> la imagen del contenedor y a SSM / variables de entorno.
