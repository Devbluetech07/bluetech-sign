import crypto from 'crypto';
import axios from 'axios';
import { query } from '../config/database';

type WebhookEvent = 'document.sent' | 'document.completed' | 'signer.signed' | 'signer.rejected';

export async function dispatchWebhook(
  organizationId: string,
  event: WebhookEvent,
  payload: Record<string, unknown>,
): Promise<void> {
  const hooks = await query(
    `SELECT id, url, secret
     FROM webhooks
     WHERE organization_id = $1
       AND active = true
       AND ($2 = ANY(events))`,
    [organizationId, event],
  );

  for (const hook of hooks.rows as Array<{ id: string; url: string; secret: string | null }>) {
    const body = { event, payload, timestamp: new Date().toISOString() };
    const secret = hook.secret ?? '';
    const signature = crypto.createHash('sha256').update(`${secret}${JSON.stringify(body)}`).digest('hex');

    let statusCode: number | null = null;
    let responseBody = '';
    let errorMessage = '';

    try {
      const response = await axios.post(hook.url, body, {
        timeout: 10000,
        headers: {
          'Content-Type': 'application/json',
          'x-bluetech-signature': signature,
        },
      });

      statusCode = response.status;
      responseBody = JSON.stringify(response.data ?? {});
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Webhook request failed';
      errorMessage = message;
      statusCode = axios.isAxiosError(error) ? (error.response?.status ?? null) : null;
      responseBody = axios.isAxiosError(error) ? JSON.stringify(error.response?.data ?? {}) : '';
    }

    await query(
      `INSERT INTO webhook_logs (organization_id, webhook_id, event, payload, status_code, response_body, error_message)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [organizationId, hook.id, event, JSON.stringify(body), statusCode, responseBody, errorMessage || null],
    );
  }
}
