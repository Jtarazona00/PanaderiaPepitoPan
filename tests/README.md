# Tests de integración

Cinco tests que validan los requerimientos no funcionales de la plataforma de
pedidos, en **Node.js puro** (18+) con `fetch` nativo y **sin dependencias
externas**.

| Test | Archivo | Qué valida |
|------|---------|------------|
| 1 | `01-smoke.test.js` | Los 3 servicios críticos responden 200 en < 1000ms |
| 2 | `02-api.test.js` | Casos críticos de la API (pedidos, disponibilidad por sede) |
| 3 | `03-fallback.test.js` | Fallback de Redis → RDS (**interactivo**, ver abajo) |
| 4 | `04-propagation.test.js` | Propagación de disponibilidad < 2000ms |
| 5 | `05-concurrent.test.js` | 50 requests concurrentes, P95 < 1000ms (RNF1) |

## Pruebas unitarias

Aparte de los 5 tests de integración, hay **pruebas unitarias** de las funciones
puras del proyecto (en `tests/unit/`, con el runner nativo `node:test`, sin
dependencias):

```bash
node --test "tests/unit/**/*.test.js"
```

Cubren `getDisponible` (parseo de disponibilidad), `isValidSede`,
`normalizeRoute`, `parseLogLevel` y `calcTotal`. No necesitan servidor.

## Cómo correrlos (integración)

Cada test es independiente:

```bash
node tests/01-smoke.test.js
```

O todos en secuencia con resumen final:

```bash
node tests/run-all.js
```

### Contra qué corren

- **Por defecto** apuntan a `http://localhost:4002`. Configúralo con la variable
  `BASE_URL`:
  ```bash
  BASE_URL=http://localhost:5002 node tests/run-all.js
  ```
- **En local con la app real:** levanta tu `docker-compose.localhost.yml` y corre
  los tests apuntando a tu backend.
- **Sin la app / en CI:** hay un servidor mock incluido que implementa los 7
  endpoints en memoria:
  ```bash
  node tests/mock-server.js &   # levanta el mock en el 4002
  node tests/run-all.js
  ```

## Test 3 (fallback de Redis)

Es **interactivo**: mide la respuesta con Redis, te pide detener Redis a mano
(`docker stop redis-localhost`) y vuelve a medir para comprobar el fallback a
RDS. En **GitHub Actions** se **auto-omite** (detecta la variable `CI`) porque no
puede esperar input ni detener contenedores.

## GitHub Actions

El workflow `.github/workflows/tests.yml` levanta el servidor mock y ejecuta la
suite en cada push. El test 3 aparece como *SKIP* (manual).
