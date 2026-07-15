// Backend mínimo (Node puro) para tener una imagen real que construir y subir.
const http = require('http');

const port = process.env.PORT || 8080;

http
  .createServer((req, res) => {
    if (req.url === '/api/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ status: 'ok' }));
    }
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('backend pepito-pan');
  })
  .listen(port, () => console.log(`backend escuchando en :${port}`));
