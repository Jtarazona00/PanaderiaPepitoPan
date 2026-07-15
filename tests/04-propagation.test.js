// ---------------------------------------------------------------------------
// TEST 4 — Propagation testing de disponibilidad
// Cambia la disponibilidad de un plato y mide cuánto tarda en reflejarse
// (debe ser < 2000ms). Luego restaura el estado.
// ---------------------------------------------------------------------------

const { pass, fail, timedFetch, connRefusedMessage, getDisponible } = require('./_helpers');

const LIMIT = 2000;
const JSON_HEADERS = { 'Content-Type': 'application/json' };

async function main() {
  console.log('TEST 4 — Propagation testing de disponibilidad\n');

  // 1. Estado inicial
  const inicial = await timedFetch('/api/disponibilidad/1');
  if (inicial.connError) return connRefusedMessage(), (process.exitCode = 1);
  const estadoInicial = getDisponible(inicial.body, 2);
  console.log(`Estado inicial del plato 2 en sede 1: ${estadoInicial}`);

  // 2. Timestamp T1
  const T1 = performance.now();

  // 3. Cambiar disponibilidad
  const put = await timedFetch('/api/disponibilidad/1/2', {
    method: 'PUT',
    headers: JSON_HEADERS,
    body: JSON.stringify({ disponible: false }),
  });
  if (put.connError) return connRefusedMessage(), (process.exitCode = 1);

  // 4. Leer inmediatamente
  const get = await timedFetch('/api/disponibilidad/1');
  if (get.connError) return connRefusedMessage(), (process.exitCode = 1);

  // 5. Timestamp T2
  const T2 = performance.now();

  // 6. Tiempo de propagación
  const propMs = Math.round(T2 - T1);
  const reflejado = getDisponible(get.body, 2) === false;
  const ok = reflejado && propMs < LIMIT;

  console.log(`Tiempo de propagación: ${propMs}ms`);
  if (ok) pass('Propagación de disponibilidad', propMs);
  else fail('Propagación de disponibilidad', propMs, !reflejado ? 'el cambio no se reflejó' : `${propMs}ms >= ${LIMIT}ms`);

  // 9. Restaurar estado
  await timedFetch('/api/disponibilidad/1/2', {
    method: 'PUT',
    headers: JSON_HEADERS,
    body: JSON.stringify({ disponible: true }),
  });
  console.log('Estado restaurado (plato 2 = true)');

  process.exitCode = ok ? 0 : 1;
}

main();
