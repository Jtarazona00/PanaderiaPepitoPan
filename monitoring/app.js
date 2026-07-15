// ---------------------------------------------------------------------------
// App de demo instrumentada con métricas Prometheus (Node.js puro, sin deps).
// Expone los endpoints de la API y un endpoint /metrics para que Prometheus
// lo scrapee y Grafana lo grafique.
// ---------------------------------------------------------------------------

const http = require('http');

const PORT = Number(process.env.PORT) || 4002;

const menu = [
  { id: 1, nombre: 'Lomo Saltado', precio: 28 },
  { id: 2, nombre: 'Ají de Gallina', precio: 24 },
  { id: 3, nombre: 'Ceviche', precio: 32 },
  { id: 4, nombre: 'Arroz con Pollo', precio: 22 },
];

// ---- Estado de métricas -----------------------------------------------------
const reqCounter = new Map(); // "method|route|status" -> count
const BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10];
const bucketCounts = new Array(BUCKETS.length).fill(0);
let durCount = 0;
let durSum = 0;
let pedidosTotal = 0;

function observe(sec) {
  durSum += sec;
  durCount += 1;
  for (let i = 0; i < BUCKETS.length; i++) {
    if (sec <= BUCKETS[i]) bucketCounts[i] += 1;
  }
}

function incRequest(method, route, status) {
  const k = `${method}|${route}|${status}`;
  reqCounter.set(k, (reqCounter.get(k) || 0) + 1);
}

// /api/disponibilidad/1 -> /api/disponibilidad/:id  (evita alta cardinalidad)
function normalizeRoute(pathname) {
  return pathname.replace(/\/\d+/g, '/:id');
}

function metricsText() {
  const out = [];
  out.push('# HELP http_requests_total Total de requests HTTP.');
  out.push('# TYPE http_requests_total counter');
  for (const [k, v] of reqCounter) {
    const [method, route, status] = k.split('|');
    out.push(`http_requests_total{method="${method}",route="${route}",status="${status}"} ${v}`);
  }
  out.push('# HELP http_request_duration_seconds Duración de las requests (segundos).');
  out.push('# TYPE http_request_duration_seconds histogram');
  for (let i = 0; i < BUCKETS.length; i++) {
    out.push(`http_request_duration_seconds_bucket{le="${BUCKETS[i]}"} ${bucketCounts[i]}`);
  }
  out.push(`http_request_duration_seconds_bucket{le="+Inf"} ${durCount}`);
  out.push(`http_request_duration_seconds_sum ${durSum}`);
  out.push(`http_request_duration_seconds_count ${durCount}`);
  out.push('# HELP pedidos_total Pedidos confirmados.');
  out.push('# TYPE pedidos_total counter');
  out.push(`pedidos_total ${pedidosTotal}`);
  out.push('# HELP up Servicio arriba (1 = ok).');
  out.push('# TYPE up gauge');
  out.push('up 1');
  return out.join('\n') + '\n';
}

function sendJson(res, status, obj, delayMs) {
  setTimeout(() => {
    res.writeHead(status, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(obj));
  }, delayMs);
}

function isValidSede(s) {
  const n = Number(s);
  return Number.isInteger(n) && n >= 1 && n <= 350;
}

function readBody(req) {
  return new Promise((resolve) => {
    let d = '';
    req.on('data', (c) => (d += c));
    req.on('end', () => {
      try {
        resolve(d ? JSON.parse(d) : {});
      } catch {
        resolve({});
      }
    });
  });
}

const server = http.createServer(async (req, res) => {
  const start = process.hrtime.bigint();
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const route = normalizeRoute(url.pathname);

  // Registrar métricas al terminar la respuesta (no contamos /metrics)
  if (url.pathname !== '/metrics') {
    res.on('finish', () => {
      const sec = Number(process.hrtime.bigint() - start) / 1e9;
      observe(sec);
      incRequest(req.method, route, res.statusCode);
    });
  }

  if (url.pathname === '/metrics') {
    res.writeHead(200, { 'Content-Type': 'text/plain; version=0.0.4' });
    return res.end(metricsText());
  }

  // Latencia simulada (5-120ms) para dar variedad al dashboard.
  const delay = 5 + Math.floor(Math.random() * 115);

  // ~2% de errores simulados para alimentar el panel de 5xx (solo demo).
  if (url.pathname.startsWith('/api/') && Math.random() < 0.02) {
    return sendJson(res, 500, { error: 'error simulado' }, delay);
  }

  const parts = url.pathname.split('/').filter(Boolean);

  if (req.method === 'GET' && url.pathname === '/api/health') {
    return sendJson(res, 200, { status: 'ok' }, delay);
  }
  if (req.method === 'GET' && url.pathname === '/api/menu') {
    return sendJson(res, 200, menu, delay);
  }
  if (req.method === 'GET' && parts[1] === 'disponibilidad' && parts.length === 3) {
    if (!isValidSede(parts[2])) return sendJson(res, 404, { error: 'sede' }, delay);
    return sendJson(res, 200, { sede_id: Number(parts[2]), disponibilidad: { 1: true, 2: false, 3: true, 4: true } }, delay);
  }
  if (req.method === 'GET' && parts[1] === 'stock' && parts.length === 3) {
    if (!isValidSede(parts[2])) return sendJson(res, 404, { error: 'sede' }, delay);
    return sendJson(res, 200, { sede_id: Number(parts[2]), stock: [] }, delay);
  }
  if (req.method === 'POST' && url.pathname === '/api/pedidos') {
    const body = await readBody(req);
    if (!isValidSede(body.sede_id)) return sendJson(res, 400, { error: 'sede' }, delay);
    pedidosTotal += 1;
    return sendJson(res, 201, { pedido_id: 1000 + pedidosTotal, estado: 'confirmado' }, delay);
  }

  return sendJson(res, 404, { error: 'ruta no encontrada' }, delay);
});

server.listen(PORT, () => console.log(`App instrumentada en http://localhost:${PORT}  (metricas en /metrics)`));
