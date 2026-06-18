# Arquitectura — Plataforma de Pedidos Online

Cadena de restaurantes con 350 sedes, menú unificado y disponibilidad de platos
por sede en tiempo real. Sin delivery: solo pedidos en local. Región **us-east-2**,
3 zonas de disponibilidad.

## Flujo de una petición

```
Usuarios / Sedes / Admin
        │ HTTPS
        ▼
   Route 53  ──►  CloudFront (CDN, TTL menú 300s)
                      │
                      ▼
              API Gateway HTTP v2  ──(VPC Link)──►  ALB  ◄── WAF v2
                                                     │
                          ┌──────────────────────────┴──────────────────────────┐
                          ▼                                                       ▼
                   ECS Fargate frontend (nginx)                        ECS Fargate backend (Node.js)
                          (3 AZ, min 4 / max 12)                          (3 AZ, min 4 / max 20)
                                                                            │            │
                                                                  cache lookup      lectura/escritura
                                                                            ▼            ▼
                                                                  ElastiCache Redis   RDS PostgreSQL 16
                                                                  (menú 300s,         (Multi-AZ primaria +
                                                                   disponibilidad      réplica de lectura)
                                                                   180s)
```

Manejo de errores asíncrono: la aplicación encola eventos en **SQS** → **Lambda**
los procesa y publica alertas en **SNS** (correo al administrador). La **DLQ**
retiene 14 días los mensajes no procesados.

## Cómo se cumplen los requerimientos no funcionales

| RNF | Requerimiento | Cómo se implementa |
|-----|---------------|--------------------|
| **RNF1** | Rendimiento P95 ≤ 1s, menú desde caché | CloudFront (TTL 300s) + Redis (menú 300s / disponibilidad 180s); fallback a réplica RDS |
| **RNF2** | Escalabilidad hasta 35 000 concurrentes, CPU < 65% | ECS autoscaling reactivo (target 65%) + scheduled scaling 10:00 / 12:30 / 19:00 / 23:00 |
| **RNF3** | Confiabilidad, no perder pedidos | RDS Multi-AZ, AWS Backup diario (30d), SQS + DLQ (14d) |
| **RNF4** | Disponibilidad 99% y tolerancia a caída de AZ | 3 AZ, ALB multi-AZ, failover RDS automático |
| **RNF5** | Seguridad: cifrado, roles mínimos, bloqueo de amenazas | KMS transversal, IAM (2 grupos), WAF v2 (OWASP + SQLi + rate 2000/IP), HTTPS |
| **RNF6** | Interoperabilidad: sincronizar disponibilidad < 2s | `PUT /disponibilidad` invalida caché Redis; reconciliación caché ↔ BD |
| **RNF7** | Tolerancia a fallos de componente individual | Health checks ALB, auto-reemplazo de tareas ECS, fallback caché → réplica RDS |

## Componentes por archivo

| Archivo | Capa |
|---------|------|
| `vpc.tf` | Red (VPC, subredes, NAT, rutas) |
| `kms.tf`, `iam.tf`, `security_groups.tf`, `waf.tf`, `ssm.tf` | Seguridad |
| `rds.tf`, `elasticache.tf`, `s3_logs.tf` | Datos y logs |
| `ecr.tf`, `alb.tf`, `ecs.tf` | Cómputo |
| `cloudfront.tf`, `apigateway.tf`, `route53.tf` | Borde |
| `sqs.tf`, `lambda.tf`, `sns.tf` | Asíncrono |
| `cloudwatch.tf`, `backup.tf` | Operación |

## Base de datos (PostgreSQL relacional)

Se elige PostgreSQL por la necesidad de **consistencia ACID** en pedidos e
inventario. Redis complementa como caché de lectura, no reemplaza la BD.

Tablas principales: `menu`, `pedidos`, `disponibilidad_sede`, `stock_sede`.
