// Generador de database.log — registra las consultas a PostgreSQL.
const fs = require('fs');
const path = require('path');

const LOG = path.join(process.env.LOG_DIR || path.join(__dirname, '..', 'logs'), 'database.log');

const queries = [
  ['SELECT', 'pedidos', 'WHERE sede_id=1'],
  ['SELECT', 'menu', ''],
  ['INSERT', 'pedidos', ''],
  ['UPDATE', 'disponibilidad_sede', 'SET disponible=false'],
  ['SELECT', 'stock_sede', 'WHERE sede_id=2'],
  ['UPDATE', 'stock_sede', 'SET cantidad=cantidad-1'],
];

function ts() {
  return new Date().toISOString().replace('T', ' ').substring(0, 19);
}

function line() {
  const [op, tbl, cond] = queries[Math.floor(Math.random() * queries.length)];
  const msg = `${op} ${tbl} ${cond}`.trim();
  const r = Math.random();
  if (r < 0.03) return `[ERROR] ${ts()} - ${msg} - connection timeout`;
  if (r < 0.12) {
    const slow = Math.floor(300 + Math.random() * 700);
    return `[WARN] ${ts()} - slow query: ${msg} - time: ${slow}ms`;
  }
  const rows = Math.floor(Math.random() * 30);
  const time = Math.floor(2 + Math.random() * 40);
  return `[INFO] ${ts()} - ${msg} - rows: ${rows} - time: ${time}ms`;
}

function start() {
  fs.mkdirSync(path.dirname(LOG), { recursive: true });
  setInterval(() => fs.appendFile(LOG, line() + '\n', () => {}), 900 + Math.random() * 400);
}

module.exports = { start };
if (require.main === module) start();
