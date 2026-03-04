import { Request, Response } from 'express';
import { query } from '../config/database';
import { delCache, getCache, setCache } from '../config/redis';
import { sendEmail } from '../services/emailService';

const ACCESS_CODE_TTL_SECONDS = 600;
interface AccessCache {
  code: string;
}

export const publicController = {
  async requestAccess(req: Request, res: Response) {
    try {
      const email = String(req.body.email || '').trim().toLowerCase();
      if (!email) return res.status(400).json({ error: 'Email e obrigatorio' });

      const code = Math.floor(100000 + Math.random() * 900000).toString();
      await setCache(`public_access:${email}`, { code }, ACCESS_CODE_TTL_SECONDS);

      const html = `
        <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto">
          <h2 style="color:#1E3A5F">BlueTech Assina</h2>
          <p>Use o codigo abaixo para acessar seus documentos:</p>
          <div style="font-size:28px;font-weight:700;letter-spacing:6px;color:#1E3A5F">${code}</div>
          <p style="color:#666;margin-top:16px">Este codigo expira em 10 minutos.</p>
        </div>
      `;

      await sendEmail({
        to: email,
        subject: 'Codigo de acesso - BlueTech Assina',
        html,
      });

      res.json({ message: 'Codigo enviado' });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao enviar codigo', details: error.message });
    }
  },

  async verifyAccess(req: Request, res: Response) {
    try {
      const email = String(req.body.email || '').trim().toLowerCase();
      const code = String(req.body.code || '').trim();
      if (!email || !code) return res.status(400).json({ error: 'Email e codigo sao obrigatorios' });

      const cache = await getCache(`public_access:${email}`) as AccessCache | null;
      if (!cache || cache.code !== code) return res.status(400).json({ error: 'Codigo invalido ou expirado' });
      await delCache(`public_access:${email}`);

      const result = await query(
        `SELECT
           ds.access_token,
           ds.status as signer_status,
           ds.signed_at,
           d.id,
           d.name as document_name,
           d.status as document_status,
           d.created_at,
           o.name as organization_name,
           o.logo_url,
           o.brand_primary_color
         FROM document_signers ds
         JOIN documents d ON d.id = ds.document_id
         JOIN organizations o ON o.id = d.organization_id
         WHERE LOWER(ds.email) = LOWER($1)
           AND d.status NOT IN ('draft', 'cancelled')
         ORDER BY d.created_at DESC
         LIMIT 50`,
        [email],
      );

      res.json({
        documents: result.rows.map((row) => ({
          id: row.id,
          name: row.document_name,
          status: row.document_status,
          signer_status: row.signer_status,
          organization_name: row.organization_name,
          logo_url: row.logo_url,
          brand_primary_color: row.brand_primary_color,
          created_at: row.created_at,
          access_token: row.access_token,
          signed_at: row.signed_at,
        })),
      });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao verificar acesso', details: error.message });
    }
  },
};
