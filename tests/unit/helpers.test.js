// ---------------------------------------------------------------------------
// Pruebas UNITARIAS de getDisponible (parseo de disponibilidad por plato).
//   Ejecutar:  node --test tests/unit/
// ---------------------------------------------------------------------------

const test = require('node:test');
const assert = require('node:assert');
const { getDisponible } = require('../_helpers');

test('getDisponible lee la forma de mapa { "1": true }', () => {
  const body = { sede_id: 1, disponibilidad: { '1': true, '2': false } };
  assert.strictEqual(getDisponible(body, 1), true);
  assert.strictEqual(getDisponible(body, 2), false);
  assert.strictEqual(getDisponible(body, '1'), true); // acepta número o string
});

test('getDisponible lee la forma de array [{ plato_id, disponible }]', () => {
  const body = { disponibilidad: [
    { plato_id: 1, disponible: true },
    { plato_id: 2, disponible: false },
  ] };
  assert.strictEqual(getDisponible(body, 1), true);
  assert.strictEqual(getDisponible(body, 2), false);
});

test('getDisponible soporta la clave alternativa "platos"', () => {
  assert.strictEqual(getDisponible({ platos: { '3': true } }, 3), true);
});

test('getDisponible soporta el valor objeto { disponible: bool }', () => {
  assert.strictEqual(getDisponible({ disponibilidad: { '1': { disponible: false } } }, 1), false);
});

test('getDisponible devuelve undefined si no encuentra el plato o el body es vacío', () => {
  assert.strictEqual(getDisponible({ disponibilidad: {} }, 9), undefined);
  assert.strictEqual(getDisponible(null, 1), undefined);
});
