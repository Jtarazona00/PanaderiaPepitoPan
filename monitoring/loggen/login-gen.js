// Generador de login.log — registra la autenticación del personal de las sedes.
const fs = require('fs');
const path = require('path');

const LOG = path.join(process.env.LOG_DIR || path.join(__dirname, '..', 'logs'), 'login.log');

const usuarios = ['caja1', 'caja2', 'caja3', 'admin', 'supervisor'];

function ts() {
  return new Date().toISOString().replace('T', ' ').substring(0, 19);
}

function line() {
  const sede = 1 + Math.floor(Math.random() * 350);
  const user = usuarios[Math.floor(Math.random() * usuarios.length)];
  const r = Math.random();
  if (r < 0.03) return `[ERROR] ${ts()} - LOGIN sede_${sede} - user: ${user} - bloqueado (3 intentos fallidos)`;
  if (r < 0.11) return `[WARN] ${ts()} - LOGIN sede_${sede} - user: ${user} - FAILED (credenciales invalidas)`;
  return `[INFO] ${ts()} - LOGIN sede_${sede} - user: ${user} - OK`;
}

function start() {
  fs.mkdirSync(path.dirname(LOG), { recursive: true });
  setInterval(() => fs.appendFile(LOG, line() + '\n', () => {}), 1500 + Math.random() * 1000);
}

module.exports = { start };
if (require.main === module) start();
