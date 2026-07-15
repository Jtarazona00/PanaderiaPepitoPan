# Caso de prueba de usuario (aceptación)

| Campo | Valor |
|-------|-------|
| **ID** | TC-U-01 |
| **Título** | Un cliente puede hacer un pedido desde la web |
| **Módulo** | Pedidos — flujo de compra |
| **Tipo** | Manual / End-to-End de interfaz (UI) |
| **Prioridad** | Alta |
| **RNF relacionado** | RNF1 (rendimiento), RNF6 (disponibilidad por sede) |

## Objetivo
Verificar que un cliente puede completar el flujo de pedido desde la interfaz
web: seleccionar sede, ver el menú, agregar un plato al carrito, confirmar y
recibir la confirmación con el ID del pedido.

## Precondiciones
- Entorno **localhost** levantado con `docker-compose.localhost.yml`
  (frontend 4001, backend 4002, base de datos 4003, Redis 4004).
- Frontend accesible en **http://localhost:4001**.
- La **Sede 1** existe y está activa.
- El menú incluye el plato **"Lomo Saltado"**.
- Navegador de escritorio actualizado (Chrome, Edge o Firefox).

## Datos de prueba
- Sede: **1**
- Plato: **Lomo Saltado** (precio S/ 28)

## Pasos

| # | Acción | Resultado esperado | Resultado obtenido | Estado |
|---|--------|--------------------|--------------------|--------|
| 1 | Abrir `http://localhost:4001` en el navegador | Carga la página de inicio de la plataforma, sin errores | | ☐ |
| 2 | Seleccionar **Sede 1** | La sede 1 queda seleccionada y la web indica que opera sobre esa sede | | ☐ |
| 3 | Ver el menú cargado | Se muestra el menú con al menos 1 plato; aparece **"Lomo Saltado"** con su precio | | ☐ |
| 4 | Agregar **Lomo Saltado** al carrito | El carrito muestra 1 ítem (Lomo Saltado) y el total se actualiza a S/ 28 | | ☐ |
| 5 | Confirmar pedido | La web envía el pedido y muestra un estado de "procesando/confirmado" | | ☐ |
| 6 | Verificar el mensaje de confirmación | Aparece **"Pedido confirmado ID: &lt;número&gt;"** (por ejemplo *Pedido confirmado ID: 142*) | | ☐ |

## Criterio de aceptación
- **PASS**: se completa el flujo de los 6 pasos y en el paso 6 aparece el
  mensaje de confirmación con un **ID de pedido**.
- **FAIL**: la web no carga, el menú no aparece, no se puede agregar o confirmar
  el pedido, o no se muestra el mensaje de confirmación con ID.

> **Nota sobre el ID:** el número **142** es solo un ejemplo. El ID se genera
> automáticamente en el backend, así que el valor real variará. Lo que se
> valida es el **formato** del mensaje: `Pedido confirmado ID: <número>`, no un
> número concreto.

## Verificación técnica de respaldo (opcional)
Para dejar evidencia adicional a la captura, con el ID obtenido se puede
consultar el pedido directamente en la API:

```bash
curl http://localhost:4002/api/pedidos/<ID>
# Debe devolver el pedido con estado "confirmado" y sede_id: 1
```

## Evidencia
_Adjuntar aquí la captura de pantalla del mensaje "Pedido confirmado ID: …"._

## Registro de ejecución

| Campo | Valor |
|-------|-------|
| Ejecutado por | |
| Fecha | |
| Ambiente | localhost / dev |
| ID de pedido obtenido | |
| **Veredicto** | ☐ PASS  ☐ FAIL |
| Observaciones | |
