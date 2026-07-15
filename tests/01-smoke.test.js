// ---------------------------------------------------------------------------
// TEST 1 — Smoke testing
// Verifica que los 3 servicios críticos respondan 200 en menos de 1000ms.
// ---------------------------------------------------------------------------

const { pass, fail, timedFetch, connRefusedMessage } = require('./_helpers');

const LIMIT = 1000;

async function main() {
  console.log('TEST 1 — Smoke testing\n');
  let failures = 0;

  // GET /api/health → { status: 'ok' }
  {
    const r = await timedFetch('/api/health');
    if (r.connError) return connRefusedMessage(), (process.exitCode = 1);
    const okStatus = r.status === 200;
    const okBody = r.body && r.body.status === 'ok';
    const okTime = r.ms < LIMIT;
    if (okStatus && okBody && okTime) pass('GET /api/health', r.ms);
    else {
      failures++;
      fail('GET /api/health', r.ms, !okStatus ? `status ${r.status}` : !okBody ? "body != { status: 'ok' }" : `${r.ms}ms >= ${LIMIT}ms`);
    }
  }

  // GET /api/menu → array con al menos 1 elemento
  {
    const r = await timedFetch('/api/menu');
    if (r.connError) return connRefusedMessage(), (process.exitCode = 1);
    const okStatus = r.status === 200;
    const okBody = Array.isArray(r.body) && r.body.length >= 1;
    const okTime = r.ms < LIMIT;
    if (okStatus && okBody && okTime) pass('GET /api/menu', r.ms);
    else {
      failures++;
      fail('GET /api/menu', r.ms, !okStatus ? `status ${r.status}` : !okBody ? 'no es un array con >= 1 elemento' : `${r.ms}ms >= ${LIMIT}ms`);
    }
  }

  // GET /api/disponibilidad/1 → objeto
  {
    const r = await timedFetch('/api/disponibilidad/1');
    if (r.connError) return connRefusedMessage(), (process.exitCode = 1);
    const okStatus = r.status === 200;
    const okBody = r.body && typeof r.body === 'object' && !Array.isArray(r.body);
    const okTime = r.ms < LIMIT;
    if (okStatus && okBody && okTime) pass('GET /api/disponibilidad/1', r.ms);
    else {
      failures++;
      fail('GET /api/disponibilidad/1', r.ms, !okStatus ? `status ${r.status}` : !okBody ? 'no es un objeto' : `${r.ms}ms >= ${LIMIT}ms`);
    }
  }

  console.log(`\nResultado: ${failures === 0 ? 'PASS' : 'FAIL'} (${3 - failures}/3 en < ${LIMIT}ms)`);
  process.exitCode = failures === 0 ? 0 : 1;
}

main();
