// ---------------------------------------------------------------------------
// Helpers compartidos por los tests. Node.js puro (18+), sin dependencias
// externas: usa fetch nativo y performance.now().
// ---------------------------------------------------------------------------

const BASE_URL = process.env.BASE_URL || 'http://localhost:4002';
const IS_CI = process.env.CI === 'true' || process.env.CI === '1';

const GREEN = '\x1b[32m';
const RED = '\x1b[31m';
const YELLOW = '\x1b[33m';
const RESET = '\x1b[0m';

function pass(name, ms) {
  console.log(`${GREEN}✅ PASS${RESET} — ${name} (${ms}ms)`);
}

function fail(name, ms, reason) {
  console.log(`${RED}❌ FAIL${RESET} — ${name} (${ms}ms) — ${reason}`);
}

function skip(name, reason) {
  console.log(`${YELLOW}⏭️  SKIP${RESET} — ${name} — ${reason}`);
}

// fetch con medición de tiempo de respuesta y manejo de errores de conexión.
async function timedFetch(path, options = {}) {
  const url = path.startsWith('http') ? path : `${BASE_URL}${path}`;
  // Connection: close evita el keep-alive para que el proceso salga limpio
  // (sin sockets colgando) tras terminar el test.
  const opts = { ...options, headers: { Connection: 'close', ...(options.headers || {}) } };
  const start = performance.now();
  try {
    const res = await fetch(url, opts);
    const text = await res.text();
    let body;
    try {
      body = text ? JSON.parse(text) : null;
    } catch {
      body = text;
    }
    const ms = Math.round(performance.now() - start);
    return { ok: true, status: res.status, body, ms };
  } catch (err) {
    const ms = Math.round(performance.now() - start);
    const code = err.cause && err.cause.code;
    const connError = code === 'ECONNREFUSED' || code === 'ECONNRESET';
    return { ok: false, connError, ms, error: err };
  }
}

// Mensaje claro cuando el servidor no está disponible.
function connRefusedMessage() {
  console.error(`${RED}El servidor no está corriendo. Levanta docker-compose primero.${RESET}`);
  console.error(`  (BASE_URL = ${BASE_URL})`);
}

// Lee la disponibilidad de un plato tolerando distintas formas de respuesta:
//   { disponibilidad: { "1": true } }               (mapa)
//   { disponibilidad: [ { plato_id: 1, disponible: true } ] }  (array)
function getDisponible(body, platoId) {
  if (!body) return undefined;
  const id = String(platoId);
  const map = body.disponibilidad || body.platos || body.availability;

  if (map && !Array.isArray(map) && typeof map === 'object') {
    if (id in map) {
      const v = map[id];
      return typeof v === 'object' && v !== null ? v.disponible : v;
    }
  }

  const arr = Array.isArray(body) ? body : Array.isArray(map) ? map : body.items;
  if (Array.isArray(arr)) {
    const found = arr.find((p) => String(p.plato_id ?? p.id) === id);
    if (found) return found.disponible;
  }
  return undefined;
}

module.exports = {
  BASE_URL,
  IS_CI,
  pass,
  fail,
  skip,
  timedFetch,
  connRefusedMessage,
  getDisponible,
};
