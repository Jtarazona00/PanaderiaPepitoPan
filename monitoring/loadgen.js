// ---------------------------------------------------------------------------
// Generador de tráfico: golpea la app continuamente para que el dashboard de
// Grafana tenga datos en movimiento. Node.js puro (fetch nativo), sin deps.
// ---------------------------------------------------------------------------

const TARGET = process.env.TARGET || 'http://localhost:4002';

const gets = [
  '/api/health',
  '/api/menu',
  '/api/disponibilidad/1',
  '/api/disponibilidad/2',
  '/api/stock/1',
  '/api/stock/5',
];

async function hit() {
  try {
    const r = Math.random();
    if (r < 0.15) {
      // Registrar un pedido
      await fetch(`${TARGET}/api/pedidos`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ sede_id: 1, items: [{ id: 1, nombre: 'Lomo Saltado', precio: 28 }] }),
      });
    } else if (r < 0.18) {
      // Ruta inexistente -> genera 404 para el panel de estados
      await fetch(`${TARGET}/api/ruta-inexistente`);
    } else {
      await fetch(`${TARGET}${gets[Math.floor(Math.random() * gets.length)]}`);
    }
  } catch {
    // La app puede estar aún arrancando; se reintenta en el próximo tick.
  }
}

console.log(`loadgen -> ${TARGET}  (~5 req/s)`);
setInterval(hit, 200);
