// ---------------------------------------------------------------------------
// Corre los 5 tests en secuencia (cada uno como proceso independiente, igual
// que `node tests/0X-....test.js`) e imprime un resumen final.
// En CI, el test 3 se auto-omite (sale con código 0).
// ---------------------------------------------------------------------------

const { spawnSync } = require('child_process');
const path = require('path');

const tests = [
  '01-smoke.test.js',
  '02-api.test.js',
  '03-fallback.test.js',
  '04-propagation.test.js',
  '05-concurrent.test.js',
];

const BASE_URL = process.env.BASE_URL || 'http://localhost:4002';

console.log('==============================================');
console.log(' Suite de tests — plataforma de pedidos');
console.log(` BASE_URL = ${BASE_URL}`);
console.log('==============================================');

const resultados = [];
for (const t of tests) {
  console.log(`\n----- ${t} -----`);
  const res = spawnSync(process.execPath, [path.join(__dirname, t)], { stdio: 'inherit' });
  resultados.push({ t, code: res.status });
}

console.log('\n==============================================');
console.log(' RESUMEN FINAL');
console.log('==============================================');

let pasaron = 0;
for (const r of resultados) {
  const estado = r.code === 0 ? '✅ PASS' : '❌ FAIL';
  if (r.code === 0) pasaron++;
  console.log(`${estado}  ${r.t}`);
}

console.log(`\n${pasaron}/${tests.length} tests pasaron`);
process.exit(pasaron === tests.length ? 0 : 1);
