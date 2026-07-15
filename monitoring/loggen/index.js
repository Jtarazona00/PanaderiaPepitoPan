// Lanza los 3 generadores de logs (app, database, login) en un solo proceso.
require('./api-gen').start();
require('./db-gen').start();
require('./login-gen').start();

const dir = process.env.LOG_DIR || '../logs';
console.log(`Generadores de logs activos -> ${dir}/{app,database,login}.log`);
