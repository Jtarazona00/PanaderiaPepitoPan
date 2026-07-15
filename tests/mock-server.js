// ---------------------------------------------------------------------------
// Servidor mock en Node.js puro (sin dependencias). Implementa los 7 endpoints
// de la API con datos en memoria y estado, para poder ejecutar los tests en
// GitHub Actions y en local sin necesitar la app real ni docker-compose.
//
// En local, si tienes la app real levantada, apunta los tests a ella con:
//   BASE_URL=http://localhost:4002 node tests/01-smoke.test.js
// y no uses este mock.
// ---------------------------------------------------------------------------

const http = require('http');

const PORT = Number(process.env.PORT) || 4002;
const MAX_SEDE = 350;

const menu = [
  { id: 1, nombre: 'Lomo Saltado', categoria: 'Fondos', precio: 28, activo: true },
  { id: 2, nombre: 'Ají de Gallina', categoria: 'Fondos', precio: 24, activo: true },
  { id: 3, nombre: 'Ceviche', categoria: 'Entradas', precio: 32, activo: true },
  { id: 4, nombre: 'Arroz con Pollo', categoria: 'Fondos', precio: 22, activo: true },
];

// disponibilidad[sede_id] = { platoId: bool }  (se siembra distinta por sede)
const disponibilidad = {};
function seedSede(sedeId) {
  if (disponibilidad[sedeId]) return;
  const d = {};
  for (const p of menu) {
    d[p.id] = (p.id + Number(sedeId)) % 2 === 0;
  }
  if (Number(sedeId) === 1) {
    d[1] = true;
    d[2] = true;
  }
  disponibilidad[sedeId] = d;
}

const stock = {};
function seedStock(sedeId) {
  if (stock[sedeId]) return;
  stock[sedeId] = menu.map((p) => ({
    plato_id: p.id,
    ingrediente: p.nombre,
    cantidad: 20,
    unidad: 'porciones',
  }));
}

let pedidoSeq = 1000;
const pedidos = {};

function send(res, status, obj) {
  res.writeHead(status, { 'Content-Type': 'application/json', Connection: 'close' });
  res.end(JSON.stringify(obj));
}

function isValidSede(sedeId) {
  const n = Number(sedeId);
  return Number.isInteger(n) && n >= 1 && n <= MAX_SEDE;
}

function readBody(req) {
  return new Promise((resolve) => {
    let data = '';
    req.on('data', (c) => (data += c));
    req.on('end', () => {
      try {
        resolve(data ? JSON.parse(data) : {});
      } catch {
        resolve({});
      }
    });
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const parts = url.pathname.split('/').filter(Boolean); // ['api','disponibilidad','1']
  const method = req.method;

  if (method === 'GET' && url.pathname === '/api/health') {
    return send(res, 200, { status: 'ok' });
  }

  if (method === 'GET' && url.pathname === '/api/menu') {
    return send(res, 200, menu);
  }

  if (method === 'GET' && parts[0] === 'api' && parts[1] === 'disponibilidad' && parts.length === 3) {
    const sede = parts[2];
    if (!isValidSede(sede)) return send(res, 404, { error: 'sede no encontrada' });
    seedSede(sede);
    return send(res, 200, { sede_id: Number(sede), disponibilidad: disponibilidad[sede] });
  }

  if (method === 'PUT' && parts[0] === 'api' && parts[1] === 'disponibilidad' && parts.length === 4) {
    const sede = parts[2];
    const plato = parts[3];
    if (!isValidSede(sede)) return send(res, 404, { error: 'sede no encontrada' });
    seedSede(sede);
    const body = await readBody(req);
    disponibilidad[sede][plato] = !!body.disponible;
    return send(res, 200, { sede_id: Number(sede), plato_id: Number(plato), disponible: !!body.disponible });
  }

  if (method === 'GET' && parts[0] === 'api' && parts[1] === 'stock' && parts.length === 3) {
    const sede = parts[2];
    if (!isValidSede(sede)) return send(res, 404, { error: 'sede no encontrada' });
    seedStock(sede);
    return send(res, 200, { sede_id: Number(sede), stock: stock[sede] });
  }

  if (method === 'POST' && url.pathname === '/api/pedidos') {
    const body = await readBody(req);
    if (!isValidSede(body.sede_id)) return send(res, 400, { error: 'sede invalida' });
    if (!Array.isArray(body.items) || body.items.length === 0) {
      return send(res, 400, { error: 'items requeridos' });
    }
    const id = ++pedidoSeq;
    const total = body.items.reduce((s, it) => s + (Number(it.precio) || 0), 0);
    pedidos[id] = {
      pedido_id: id,
      sede_id: body.sede_id,
      items: body.items,
      total,
      estado: 'confirmado',
      created_at: new Date().toISOString(),
    };
    return send(res, 201, pedidos[id]);
  }

  if (method === 'GET' && parts[0] === 'api' && parts[1] === 'pedidos' && parts.length === 3) {
    const p = pedidos[parts[2]];
    if (!p) return send(res, 404, { error: 'pedido no encontrado' });
    return send(res, 200, p);
  }

  return send(res, 404, { error: 'ruta no encontrada' });
});

server.listen(PORT, () => {
  console.log(`Mock server escuchando en http://localhost:${PORT}`);
});
