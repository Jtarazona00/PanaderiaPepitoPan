// ---------------------------------------------------------------------------
// TEST 3 — Fallback testing de Redis
// Mide la respuesta con Redis, pide detener Redis a mano y vuelve a medir para
// comprobar el fallback a la réplica RDS (< 1500ms).
//
// Es INTERACTIVO. En CI (variable CI) se auto-omite porque no puede esperar
// input ni detener contenedores.
// ---------------------------------------------------------------------------

const readline = require('readline');
const { pass, fail, skip, timedFetch, connRefusedMessage, IS_CI } = require('./_helpers');

const LIMIT = 1500;

function ask(question) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(question, (ans) => {
      rl.close();
      resolve(ans);
    });
  });
}

async function main() {
  console.log('TEST 3 — Fallback testing de Redis\n');

  // 1. Con Redis activo
  const conRedis = await timedFetch('/api/disponibilidad/1');
  if (conRedis.connError) return connRefusedMessage(), (process.exitCode = 1);
  console.log(`Con Redis: ${conRedis.ms}ms (esperado < 200ms)`);

  // En CI no se puede detener Redis ni esperar input.
  if (IS_CI) {
    skip('Test 3 (fallback Redis)', 'requiere detener Redis manualmente; se omite en CI');
    console.log('\nResultado: SKIP (prueba manual, no ejecutable en CI)');
    process.exitCode = 0;
    return;
  }

  // 2 y 3. Instrucción + espera de input
  console.log('\nDetén Redis ahora: docker stop redis-localhost (o redis-dev)');
  await ask('Presiona Enter cuando Redis esté detenido...');

  // 4. Sin Redis (fallback a RDS)
  const sinRedis = await timedFetch('/api/disponibilidad/1');
  if (sinRedis.connError) return connRefusedMessage(), (process.exitCode = 1);

  // 5 y 6. Evaluar
  const ok = sinRedis.status !== 500 && sinRedis.status === 200 && sinRedis.ms < LIMIT;
  if (ok) pass('Fallback a RDS sin Redis', sinRedis.ms);
  else fail('Fallback a RDS sin Redis', sinRedis.ms, sinRedis.status === 500 ? 'error 500' : sinRedis.status !== 200 ? `status ${sinRedis.status}` : `${sinRedis.ms}ms >= ${LIMIT}ms`);

  // Comparación
  console.log(`\nComparación:  con Redis ${conRedis.ms}ms   vs   sin Redis ${sinRedis.ms}ms`);
  console.log('\nReinicia Redis: docker start redis-localhost');
  process.exitCode = ok ? 0 : 1;
}

main();
