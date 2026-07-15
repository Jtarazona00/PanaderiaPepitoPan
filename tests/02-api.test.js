// ---------------------------------------------------------------------------
// TEST 2 — API testing de casos críticos
// Casos A (pedido válido), B (sede inválida), C (disponibilidad por sede),
// D (actualización de disponibilidad se refleja).
// ---------------------------------------------------------------------------

const { pass, fail, timedFetch, connRefusedMessage, getDisponible } = require('./_helpers');

const JSON_HEADERS = { 'Content-Type': 'application/json' };

async function main() {
  console.log('TEST 2 — API testing de casos críticos\n');
  let failures = 0;

  // Caso A: POST /api/pedidos con plato disponible en sede 1 → 201 + pedido_id
  {
    const r = await timedFetch('/api/pedidos', {
      method: 'POST',
      headers: JSON_HEADERS,
      body: JSON.stringify({ sede_id: 1, items: [{ id: 1, nombre: 'Lomo Saltado', precio: 28 }] }),
    });
    if (r.connError) return connRefusedMessage(), (process.exitCode = 1);
    const ok = r.status === 201 && r.body && r.body.pedido_id !== undefined;
    if (ok) pass('Caso A: POST pedido válido (201 + pedido_id)', r.ms);
    else {
      failures++;
      fail('Caso A: POST pedido válido', r.ms, `status ${r.status}, pedido_id=${r.body && r.body.pedido_id}`);
    }
  }

  // Caso B: POST /api/pedidos con sede inválida (999) → 4xx o sin pedido
  {
    const r = await timedFetch('/api/pedidos', {
      method: 'POST',
      headers: JSON_HEADERS,
      body: JSON.stringify({ sede_id: 999, items: [{ id: 1, nombre: 'Lomo Saltado', precio: 28 }] }),
    });
    if (r.connError) return connRefusedMessage(), (process.exitCode = 1);
    const sinPedido = !(r.body && r.body.pedido_id !== undefined);
    const ok = (r.status >= 400 && r.status < 500) || sinPedido;
    if (ok) pass('Caso B: POST sede inválida rechazado', r.ms);
    else {
      failures++;
      fail('Caso B: POST sede inválida', r.ms, `status ${r.status} y sí generó pedido`);
    }
  }

  // Caso C: GET disponibilidad/1 vs /2 → objetos distintos
  {
    const r1 = await timedFetch('/api/disponibilidad/1');
    const r2 = await timedFetch('/api/disponibilidad/2');
    if (r1.connError || r2.connError) return connRefusedMessage(), (process.exitCode = 1);
    const ms = Math.max(r1.ms, r2.ms);
    const distintos = JSON.stringify(r1.body) !== JSON.stringify(r2.body);
    if (distintos) pass('Caso C: disponibilidad sede 1 != sede 2', ms);
    else {
      failures++;
      fail('Caso C: disponibilidad por sede', ms, 'sede 1 y sede 2 retornan lo mismo');
    }
  }

  // Caso D: PUT disponibilidad/1/1 { disponible:false } → GET refleja false
  {
    const put = await timedFetch('/api/disponibilidad/1/1', {
      method: 'PUT',
      headers: JSON_HEADERS,
      body: JSON.stringify({ disponible: false }),
    });
    if (put.connError) return connRefusedMessage(), (process.exitCode = 1);
    const get = await timedFetch('/api/disponibilidad/1');
    if (get.connError) return connRefusedMessage(), (process.exitCode = 1);
    const val = getDisponible(get.body, 1);
    const ms = put.ms + get.ms;
    if (val === false) pass('Caso D: PUT disponible=false se refleja en GET', ms);
    else {
      failures++;
      fail('Caso D: PUT disponibilidad', ms, `plato 1 = ${val} (esperado false)`);
    }
    // Restaurar estado
    await timedFetch('/api/disponibilidad/1/1', {
      method: 'PUT',
      headers: JSON_HEADERS,
      body: JSON.stringify({ disponible: true }),
    });
  }

  console.log(`\nResultado: ${failures === 0 ? 'PASS' : 'FAIL'} (${4 - failures}/4 casos)`);
  process.exitCode = failures === 0 ? 0 : 1;
}

main();
