// ---------------------------------------------------------------------------
// Utilidades puras del proyecto (sin IO ni red), fáciles de probar de forma
// unitaria. Las usa el servidor mock y reflejan la lógica de la app.
// ---------------------------------------------------------------------------

// ¿La sede está en el rango válido (1..max)?
function isValidSede(sede, max = 350) {
  const n = Number(sede);
  return Number.isInteger(n) && n >= 1 && n <= max;
}

// Normaliza una ruta reemplazando los segmentos numéricos por :id
//   /api/disponibilidad/1  ->  /api/disponibilidad/:id
function normalizeRoute(pathname) {
  return String(pathname).replace(/\/\d+/g, '/:id');
}

// Extrae el nivel de una línea de log: "[INFO] ..." -> "INFO"
function parseLogLevel(line) {
  const m = /^\[(INFO|WARN|ERROR)\]/.exec(line || '');
  return m ? m[1] : null;
}

// Suma el precio de los items de un pedido (tolerante a datos faltantes).
function calcTotal(items) {
  if (!Array.isArray(items)) return 0;
  return items.reduce((sum, it) => sum + (Number(it && it.precio) || 0), 0);
}

module.exports = { isValidSede, normalizeRoute, parseLogLevel, calcTotal };
