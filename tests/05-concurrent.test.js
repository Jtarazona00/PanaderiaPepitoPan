// ---------------------------------------------------------------------------
// TEST 5 — Concurrent requests testing
// Simula 50 usuarios consultando GET /api/menu a la vez y valida que el 95%
// responda en menos de 1000ms (equivale al P95 del RNF1).
// ---------------------------------------------------------------------------

const { pass, fail, timedFetch, connRefusedMessage } = require('./_helpers');

const N = 50;
const LIMIT = 1000;

async function main() {
  console.log('TEST 5 — Concurrent requests testing\n');

  // 1 y 2. 50 promesas paralelas con Promise.all
  const start = performance.now();
  const results = await Promise.all(
    Array.from({ length: N }, () => timedFetch('/api/menu'))
  );
  const totalMs = Math.round(performance.now() - start);

  if (results.some((r) => r.connError)) return connRefusedMessage(), (process.exitCode = 1);

  // 3 y 4. Métricas
  const exitosos = results.filter((r) => r.status === 200).length;
  const fallidos = N - exitosos;
  const tiempos = results.map((r) => r.ms).sort((a, b) => a - b);
  const avg = Math.round(tiempos.reduce((s, t) => s + t, 0) / N);
  const p95 = tiempos[Math.ceil(0.95 * N) - 1];
  const bajoLimite = results.filter((r) => r.ms < LIMIT).length;
  const pct = (bajoLimite / N) * 100;

  // 5 y 6. PASS si el 95% responde en < 1000ms
  const ok = pct >= 95;

  console.log(`- Total requests: ${N}`);
  console.log(`- Exitosos: ${exitosos}`);
  console.log(`- Fallidos: ${fallidos}`);
  console.log(`- Tiempo promedio: ${avg}ms`);
  console.log(`- P95 (percentil 95): ${p95}ms`);
  console.log(`- Requests bajo ${LIMIT}ms: ${bajoLimite}/${N}`);
  console.log(`- Tiempo total (paralelo): ${totalMs}ms`);
  console.log(`- Resultado: ${ok ? 'PASS' : 'FAIL'}`);
  console.log('');

  if (ok) pass(`50 requests concurrentes (${pct.toFixed(0)}% < ${LIMIT}ms)`, avg);
  else fail('50 requests concurrentes', avg, `solo ${pct.toFixed(0)}% < ${LIMIT}ms (se requiere >= 95%)`);

  process.exitCode = ok ? 0 : 1;
}

main();
