// ---------------------------------------------------------------------------
// Pruebas UNITARIAS de las utilidades puras (node:test, sin dependencias).
//   Ejecutar:  node --test tests/unit/
// ---------------------------------------------------------------------------

const test = require('node:test');
const assert = require('node:assert');
const { isValidSede, normalizeRoute, parseLogLevel, calcTotal } = require('../lib');

test('isValidSede acepta sedes dentro del rango 1..350', () => {
  assert.strictEqual(isValidSede(1), true);
  assert.strictEqual(isValidSede(350), true);
  assert.strictEqual(isValidSede('42'), true);
});

test('isValidSede rechaza fuera de rango o no numéricas', () => {
  assert.strictEqual(isValidSede(0), false);
  assert.strictEqual(isValidSede(999), false);
  assert.strictEqual(isValidSede(-1), false);
  assert.strictEqual(isValidSede('abc'), false);
  assert.strictEqual(isValidSede(1.5), false);
});

test('normalizeRoute reemplaza los segmentos numéricos por :id', () => {
  assert.strictEqual(normalizeRoute('/api/disponibilidad/1'), '/api/disponibilidad/:id');
  assert.strictEqual(normalizeRoute('/api/disponibilidad/1/2'), '/api/disponibilidad/:id/:id');
  assert.strictEqual(normalizeRoute('/api/menu'), '/api/menu');
});

test('parseLogLevel extrae el nivel de la línea de log', () => {
  assert.strictEqual(parseLogLevel('[INFO] 2026-07-15 - GET /api/menu'), 'INFO');
  assert.strictEqual(parseLogLevel('[WARN] slow query'), 'WARN');
  assert.strictEqual(parseLogLevel('[ERROR] connection timeout'), 'ERROR');
  assert.strictEqual(parseLogLevel('linea sin nivel'), null);
  assert.strictEqual(parseLogLevel(''), null);
});

test('calcTotal suma los precios de los items del pedido', () => {
  assert.strictEqual(calcTotal([{ precio: 28 }, { precio: 24 }]), 52);
  assert.strictEqual(calcTotal([{ precio: 10 }]), 10);
  assert.strictEqual(calcTotal([]), 0);
  assert.strictEqual(calcTotal(null), 0);
  assert.strictEqual(calcTotal([{ nombre: 'sin precio' }]), 0);
});
