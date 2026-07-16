// ---------------------------------------------------------------------------
// Lambda Error — consume la cola SQS y envía la alerta por correo con SES
// a los administradores de las 350 sedes.
//
//   SQS --> [esta Lambda] --> SES --> correo
//
// El SDK de AWS v3 viene incluido en el runtime nodejs20.x (no requiere deps).
// ---------------------------------------------------------------------------

const { SESClient, SendEmailCommand } = require('@aws-sdk/client-ses');

const ses = new SESClient({});
const SES_SENDER = process.env.SES_SENDER;
const ADMIN_EMAIL = process.env.ADMIN_EMAIL;
const ENVIRONMENT = process.env.ENVIRONMENT || 'dev';

function parseEvento(body) {
  try {
    return JSON.parse(body);
  } catch {
    return { motivo: body };
  }
}

function cuerpoCorreo(evento) {
  return [
    'Se detecto un incidente en la plataforma de pedidos.',
    '',
    `Ambiente: ${evento.ambiente || ENVIRONMENT}`,
    `Alarma:   ${evento.alarma || 'N/D'}`,
    `Estado:   ${evento.estado || 'N/D'}`,
    `Motivo:   ${evento.motivo || 'N/D'}`,
    `Fecha:    ${evento.timestamp || new Date().toISOString()}`,
  ].join('\n');
}

exports.handler = async (event) => {
  const records = event.Records || [];

  // Sin remitente verificado o destinatario no se puede enviar: se registra y sale.
  if (!SES_SENDER || !ADMIN_EMAIL) {
    console.warn('SES_SENDER o ADMIN_EMAIL no configurados: no se envia correo.');
    return { procesados: 0, omitidos: records.length };
  }

  for (const record of records) {
    const evento = parseEvento(record.body);

    await ses.send(
      new SendEmailCommand({
        Source: SES_SENDER,
        Destination: { ToAddresses: [ADMIN_EMAIL] },
        Message: {
          Subject: {
            Data: `[${evento.ambiente || ENVIRONMENT}] Alerta: ${evento.alarma || 'error en la plataforma'}`,
          },
          Body: { Text: { Data: cuerpoCorreo(evento) } },
        },
      })
    );

    console.log(`Alerta enviada por SES: ${evento.alarma || 'incidente'}`);
  }

  return { procesados: records.length };
};
