import nodemailer from 'nodemailer';
import { query } from '../config/database';
import { env } from '../config/env';

const transporter = nodemailer.createTransport({
  host: env.smtp.host,
  port: env.smtp.port,
  secure: false,
  auth: {
    user: env.smtp.user,
    pass: env.smtp.pass,
  },
});

interface EmailOptions {
  to: string;
  subject: string;
  html: string;
  from?: string;
}

export async function sendEmail(options: EmailOptions): Promise<boolean> {
  try {
    if (!env.smtp.user) {
      console.log(`📧 [EMAIL SIMULADO] Para: ${options.to} | Assunto: ${options.subject}`);
      return true;
    }
    await transporter.sendMail({
      from: options.from || `"${env.smtp.fromName}" <${env.smtp.user}>`,
      to: options.to,
      subject: options.subject,
      html: options.html,
    });
    return true;
  } catch (error) {
    console.error('Erro ao enviar email:', error);
    return false;
  }
}

export function buildSigningEmail(signerName: string, documentName: string, senderName: string, signingUrl: string, message?: string, orgColor = '#1E3A5F') {
  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f4f6f9;font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif">
<table width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden;margin-top:40px;box-shadow:0 4px 24px rgba(0,0,0,0.08)">
  <tr><td style="background:${orgColor};padding:32px 40px;text-align:center">
    <h1 style="color:#fff;margin:0;font-size:24px;font-weight:700">BlueTech Assina</h1>
    <p style="color:rgba(255,255,255,0.8);margin:8px 0 0;font-size:14px">Assinatura Digital Segura</p>
  </td></tr>
  <tr><td style="padding:40px">
    <h2 style="color:#1a1a2e;margin:0 0 16px;font-size:20px">Olá, ${signerName}!</h2>
    <p style="color:#4a5568;line-height:1.6;margin:0 0 16px">${senderName} enviou o documento <strong>"${documentName}"</strong> para sua assinatura.</p>
    ${message ? `<div style="background:#f0f4ff;border-left:4px solid ${orgColor};padding:16px;border-radius:0 8px 8px 0;margin:16px 0"><p style="color:#4a5568;margin:0;font-style:italic">"${message}"</p></div>` : ''}
    <div style="text-align:center;margin:32px 0">
      <a href="${signingUrl}" style="display:inline-block;background:${orgColor};color:#fff;text-decoration:none;padding:14px 40px;border-radius:8px;font-size:16px;font-weight:600;box-shadow:0 4px 12px rgba(30,58,95,0.3)">Assinar Documento</a>
    </div>
    <div style="background:#fef3c7;border-radius:8px;padding:16px;margin:24px 0">
      <p style="color:#92400e;margin:0;font-size:13px"><strong>⚠️ Importante:</strong> Este link é pessoal e intransferível. Não compartilhe.</p>
    </div>
    <p style="color:#718096;font-size:13px;margin:24px 0 0">Se você não reconhece este envio, ignore este email.</p>
  </td></tr>
  <tr><td style="background:#f7f8fa;padding:24px 40px;text-align:center;border-top:1px solid #e2e8f0">
    <p style="color:#a0aec0;margin:0;font-size:12px">Documento enviado via <strong>BlueTech Assina</strong></p>
    <p style="color:#cbd5e0;margin:8px 0 0;font-size:11px">© ${new Date().getFullYear()} BlueTech Films. Todos os direitos reservados.</p>
  </td></tr>
</table>
</body></html>`;
}

export function buildReminderEmail(signerName: string, documentName: string, signingUrl: string, orgColor = '#1E3A5F') {
  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;background:#f4f6f9;font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif">
<table width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;margin:40px auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08)">
  <tr><td style="background:${orgColor};padding:32px 40px;text-align:center">
    <h1 style="color:#fff;margin:0;font-size:24px">BlueTech Assina</h1>
  </td></tr>
  <tr><td style="padding:40px">
    <h2 style="color:#1a1a2e;margin:0 0 16px">Lembrete de Assinatura</h2>
    <p style="color:#4a5568;line-height:1.6">Olá ${signerName}, o documento <strong>"${documentName}"</strong> ainda aguarda sua assinatura.</p>
    <div style="text-align:center;margin:32px 0">
      <a href="${signingUrl}" style="display:inline-block;background:${orgColor};color:#fff;text-decoration:none;padding:14px 40px;border-radius:8px;font-size:16px;font-weight:600">Assinar Agora</a>
    </div>
  </td></tr>
  <tr><td style="background:#f7f8fa;padding:20px;text-align:center;border-top:1px solid #e2e8f0">
    <p style="color:#a0aec0;margin:0;font-size:12px">BlueTech Assina © ${new Date().getFullYear()}</p>
  </td></tr>
</table>
</body></html>`;
}

export function buildTokenEmail(signerName: string, token: string, orgColor = '#1E3A5F') {
  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;background:#f4f6f9;font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif">
<table width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;margin:40px auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08)">
  <tr><td style="background:${orgColor};padding:32px 40px;text-align:center">
    <h1 style="color:#fff;margin:0;font-size:24px">Código de Verificação</h1>
  </td></tr>
  <tr><td style="padding:40px;text-align:center">
    <p style="color:#4a5568;font-size:16px">Olá ${signerName}, use o código abaixo para confirmar sua assinatura:</p>
    <div style="background:#f0f4ff;border-radius:12px;padding:24px;margin:24px 0;display:inline-block">
      <span style="font-size:36px;font-weight:700;letter-spacing:8px;color:${orgColor}">${token}</span>
    </div>
    <p style="color:#a0aec0;font-size:13px">Este código expira em 10 minutos.</p>
  </td></tr>
</table>
</body></html>`;
}

export async function createNotification(data: { organization_id: string; document_id: string; signer_id: string; type: string; recipient: string; subject: string; body: string; }) {
  await query(
    `INSERT INTO notifications (organization_id, document_id, signer_id, type, recipient, subject, body, status, sent_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, 'sent', NOW())`,
    [data.organization_id, data.document_id, data.signer_id, data.type, data.recipient, data.subject, data.body]
  );
}
