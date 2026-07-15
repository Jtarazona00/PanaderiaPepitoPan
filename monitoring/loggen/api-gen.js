// Generador de app.log — registra las requests a la API de pedidos.
const fs = require('fs');
const path = require('path');

const LOG = path.join(process.env.LOG_DIR || path.join(__dirname, '..', 'logs'), 'app.log');

const routes = [
  ['GET', '/api/menu'],
  ['GET', '/api/disponibilidad/1'],
  ['GET', '/api/disponibilidad/2'],
  ['GET', '/api/stock/1'],
  ['POST', '/api/pedidos'],
  ['GET', '/api/pedidos/1042'],
  ['PUT', '/api/disponibilidad/1/2'],
  ['GET', '/api/health'],
];

function ts() {
  return new Date().toISOString().replace('T', ' ').substring(0, 19);
}

function line() {
  const [method, route] = routes[Math.floor(Math.random() * routes.length)];
  const time = Math.floor(20 + Math.random() * 200);
  const r = Math.random();
  if (r < 0.05) return `[ERROR] ${ts()} - ${method} ${route} - status: 500 - time: ${time}ms`;
  if (r < 0.15) return `[WARN] ${ts()} - ${method} ${route} - status: 404 - time: ${time}ms`;
  const status = method === 'POST' ? 201 : 200;
  return `[INFO] ${ts()} - ${method} ${route} - status: ${status} - time: ${time}ms`;
}

function start() {
  fs.mkdirSync(path.dirname(LOG), { recursive: true });
  setInterval(() => fs.appendFile(LOG, line() + '\n', () => {}), 800 + Math.random() * 400);
}

module.exports = { start };
if (require.main === module) start();
