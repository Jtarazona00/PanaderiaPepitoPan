// ---------------------------------------------------------------------------
// Lambda Trigger — recibe la notificación de la alarma de CloudWatch (vía SNS)
// y encola el evento de error en SQS para su procesamiento asíncrono.
//
//   CloudWatch --(SNS)--> [esta Lambda] --> SQS
//
// El SDK de AWS v3 viene incluido en el runtime nodejs20.x (no requiere deps).
// ---------------------------------------------------------------------------

const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');

const sqs = new SQSClient({});
const QUEUE_URL = process.env.SQS_QUEUE_URL;
const ENVIRONMENT = process.env.ENVIRONMENT || 'dev';

// El mensaje de SNS puede venir como JSON de la alarma o como texto plano.
function parseAlarma(mensaje) {
  try {
    return JSON.parse(mensaje);
  } catch {
    return { NewStateReason: mensaje };
  }
}

exports.handler = async (event) => {
  const records = event.Records || [];

  for (const record of records) {
    const sns = record.Sns || {};
    const alarma = parseAlarma(sns.Message);

    const payload = {
      origen: 'cloudwatch-alarm',
      asunto: sns.Subject || 'Alerta de la plataforma',
      alarma: alarma.AlarmName || null,
      estado: alarma.NewStateValue || null,
      motivo: alarma.NewStateReason || null,
      ambiente: ENVIRONMENT,
      timestamp: new Date().toISOString(),
    };

    await sqs.send(
      new SendMessageCommand({
        QueueUrl: QUEUE_URL,
        MessageBody: JSON.stringify(payload),
      })
    );

    console.log(`Evento encolado en SQS: ${payload.alarma || payload.asunto}`);
  }

  return { encolados: records.length };
};
