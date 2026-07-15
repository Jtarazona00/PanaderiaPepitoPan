# Monitoreo local con Grafana + Prometheus

Dashboard de las métricas esenciales del proyecto, montado 100% con Docker y
provisionado como código (data source y dashboard versionados).

```
 app (/metrics)  ──scrape──►  Prometheus  ──query──►  Grafana (dashboard)
      ▲
   loadgen  (genera tráfico para que haya datos)
```

## Cómo levantarlo

```bash
cd monitoring
docker compose up -d
```

- **Grafana:** http://localhost:3000 → usuario `admin` / clave `admin`
  (o acceso anónimo de solo lectura ya habilitado).
  El dashboard **"Pedidos — Panel esencial (RNF)"** aparece solo.
- **Prometheus:** http://localhost:9090 (para inspeccionar las métricas crudas).
- La app instrumentada responde en http://localhost:4002 (`/metrics`).

Espera ~30-60s a que Prometheus junte un par de muestras y verás los paneles con
datos en movimiento.

## Qué muestra el dashboard

| Panel | Métrica | RNF relacionado |
|-------|---------|-----------------|
| Throughput | requests por segundo | escalabilidad |
| Latencia P95 | `histogram_quantile(0.95, ...)` (rojo si ≥ 1s) | **RNF1** (P95 < 1000ms) |
| Tasa de errores 5xx | % de respuestas 5xx (rojo si ≥ 1%) | fiabilidad |
| Pedidos confirmados | contador de negocio | funcional |
| Requests por ruta | tráfico por endpoint | — |
| Latencia P50 / P95 | percentiles en el tiempo | RNF1 |
| Códigos de estado | 200 / 4xx / 5xx por segundo | — |
| Pedidos por minuto | throughput de negocio | — |

## Métricas expuestas por la app (`/metrics`)

- `http_requests_total{method,route,status}` — contador de requests.
- `http_request_duration_seconds` — histograma de latencia.
- `pedidos_total` — pedidos confirmados.
- `up` — servicio arriba.

> La app incluye una latencia simulada (5-120ms) y ~2% de errores simulados
> **solo para que el dashboard tenga datos realistas en la demo**. Para
> monitorear tu app real, apunta Prometheus a su endpoint `/metrics` en
> `prometheus.yml`.

## Logs (Grafana + Loki + Promtail)

Además de las métricas (Prometheus), el stack incluye **agregación de logs**:

```
 generadores (loggen/) ─► app.log · database.log · login.log
        │  Promtail (tail)
        ▼
      Loki  ─►  Grafana (dashboard "Pedidos — Logs")
```

- **3 generadores** (`loggen/api-gen.js`, `db-gen.js`, `login-gen.js`) escriben
  logs con niveles `INFO/WARN/ERROR` en `monitoring/logs/` — los puedes abrir en
  el editor para ver el contenido.
- **Promtail** los lee y los etiqueta por `service` (app / database / auth).
- **Loki** los almacena e indexa.
- En **Grafana** hay un segundo data source (Loki) y el dashboard
  **"Pedidos — Logs (Loki)"**: errores/warnings, volumen por servicio, logs por
  nivel y un **stream de logs en vivo** (consultas LogQL).

Los archivos `.log` se generan solos al levantar el stack y están en
`.gitignore` (no se versionan).

## Apagar

```bash
docker compose down
```
