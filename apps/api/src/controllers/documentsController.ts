import { Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import crypto from 'crypto';
import { query } from '../config/database';
import { uploadFile, getFileUrl, deleteFile, getFileBuffer } from '../config/minio';
import { AuthRequest } from '../middleware/auth';
import { createAuditLog } from '../services/auditService';
import { sendEmail, buildSigningEmail, createNotification } from '../services/emailService';
import { clearCachePattern, setCache, getCache } from '../config/redis';
import { env } from '../config/env';

export const documentsController = {
  // GET /api/documents
  async list(req: AuthRequest, res: Response) {
    try {
      const { status, folder_id, search, page = 1, limit = 20, sort = 'created_at', order = 'DESC' } = req.query;
      const offset = (Number(page) - 1) * Number(limit);
      let sql = `SELECT d.*, u.name as created_by_name, f.name as folder_name,
        (SELECT COUNT(*) FROM document_signers WHERE document_id = d.id) as total_signers,
        (SELECT COUNT(*) FROM document_signers WHERE document_id = d.id AND status = 'signed') as signed_count
        FROM documents d
        LEFT JOIN users u ON u.id = d.created_by
        LEFT JOIN folders f ON f.id = d.folder_id
        WHERE d.organization_id = $1`;
      const params: any[] = [req.user!.organization_id];
      let idx = 2;

      if (status) { sql += ` AND d.status = $${idx++}`; params.push(status); }
      if (folder_id) { sql += ` AND d.folder_id = $${idx++}`; params.push(folder_id); }
      if (search) { sql += ` AND (d.name ILIKE $${idx} OR d.file_name ILIKE $${idx})`; params.push(`%${search}%`); idx++; }

      const countResult = await query(sql.replace(/SELECT d\.\*.*FROM/, 'SELECT COUNT(*) as total FROM'), params);
      const allowedSorts = ['created_at', 'name', 'status', 'updated_at'];
      const sortField = allowedSorts.includes(sort as string) ? sort : 'created_at';
      sql += ` ORDER BY d.${sortField} ${order === 'ASC' ? 'ASC' : 'DESC'} LIMIT $${idx++} OFFSET $${idx++}`;
      params.push(Number(limit), offset);

      const result = await query(sql, params);

      res.json({
        documents: result.rows,
        pagination: { total: parseInt(countResult.rows[0]?.total || '0'), page: Number(page), limit: Number(limit), pages: Math.ceil((countResult.rows[0]?.total || 0) / Number(limit)) },
      });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao listar documentos', details: error.message });
    }
  },

  // GET /api/documents/:id
  async getById(req: AuthRequest, res: Response) {
    try {
      const result = await query(
        `SELECT d.*, u.name as created_by_name, f.name as folder_name
         FROM documents d
         LEFT JOIN users u ON u.id = d.created_by
         LEFT JOIN folders f ON f.id = d.folder_id
         WHERE d.id = $1 AND d.organization_id = $2`,
        [req.params.id, req.user!.organization_id]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'Documento não encontrado' });

      const doc = result.rows[0];
      if (doc.file_key) doc.file_url = await getFileUrl(doc.file_key);
      if (doc.signed_file_key) doc.signed_file_url = await getFileUrl(doc.signed_file_key);

      const signers = await query(
        'SELECT * FROM document_signers WHERE document_id = $1 ORDER BY sign_order ASC, created_at ASC',
        [req.params.id]
      );
      const fields = await query('SELECT * FROM document_fields WHERE document_id = $1', [req.params.id]);
      const logs = await query(
        `SELECT al.*, u.name as user_name FROM audit_logs al LEFT JOIN users u ON u.id = al.user_id
         WHERE al.document_id = $1 ORDER BY al.created_at ASC`, [req.params.id]
      );

      res.json({ ...doc, signers: signers.rows, fields: fields.rows, audit_log: logs.rows });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao buscar documento', details: error.message });
    }
  },

  // POST /api/documents/upload
  async upload(req: AuthRequest, res: Response) {
    try {
      if (!req.file) return res.status(400).json({ error: 'Arquivo é obrigatório' });

      const file = req.file;
      const fileHash = crypto.createHash('sha256').update(file.buffer).digest('hex');
      const ext = file.originalname.split('.').pop();
      const key = `documents/${req.user!.organization_id}/${uuidv4()}.${ext}`;

      await uploadFile(key, file.buffer, file.mimetype, { 'original-name': file.originalname, 'uploaded-by': req.user!.id });

      const result = await query(
        `INSERT INTO documents (organization_id, name, file_key, file_name, file_size, file_type, file_hash, folder_id, created_by, status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'draft') RETURNING *`,
        [req.user!.organization_id, req.body.name || file.originalname.replace(`.${ext}`, ''),
         key, file.originalname, file.size, file.mimetype, fileHash, req.body.folder_id || null, req.user!.id]
      );

      await createAuditLog({ organization_id: req.user!.organization_id, document_id: result.rows[0].id,
        user_id: req.user!.id, action: 'document_uploaded', description: `Documento "${file.originalname}" enviado`,
        ip_address: req.ip, user_agent: req.headers['user-agent'] as string });

      const doc = result.rows[0];
      doc.file_url = await getFileUrl(key);
      res.status(201).json(doc);
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao fazer upload', details: error.message });
    }
  },

  // PUT /api/documents/:id
  async update(req: AuthRequest, res: Response) {
    try {
      const { name, description, folder_id, deadline_at, message, sequence_enabled, remind_interval, auto_close } = req.body;
      const result = await query(
        `UPDATE documents SET name = COALESCE($1, name), description = COALESCE($2, description),
         folder_id = COALESCE($3, folder_id), deadline_at = COALESCE($4, deadline_at),
         message = COALESCE($5, message), sequence_enabled = COALESCE($6, sequence_enabled),
         remind_interval = COALESCE($7, remind_interval), auto_close = COALESCE($8, auto_close)
         WHERE id = $9 AND organization_id = $10 RETURNING *`,
        [name, description, folder_id, deadline_at, message, sequence_enabled, remind_interval, auto_close,
         req.params.id, req.user!.organization_id]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'Documento não encontrado' });
      res.json(result.rows[0]);
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao atualizar documento', details: error.message });
    }
  },

  // POST /api/documents/:id/signers
  async addSigner(req: AuthRequest, res: Response) {
    try {
      const { name, email, cpf, phone, signature_type, auth_method, sign_order, message, metadata } = req.body;
      if (!name || !email) return res.status(400).json({ error: 'Nome e email são obrigatórios' });

      // Verificar se doc existe e está em draft
      const doc = await query('SELECT * FROM documents WHERE id = $1 AND organization_id = $2', [req.params.id, req.user!.organization_id]);
      if (doc.rows.length === 0) return res.status(404).json({ error: 'Documento não encontrado' });

      // Criar ou encontrar contato
      const contactResult = await query(
        `INSERT INTO contacts (organization_id, name, email, cpf, phone, created_by) VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (organization_id, email) DO UPDATE SET name = COALESCE(EXCLUDED.name, contacts.name) RETURNING id`,
        [req.user!.organization_id, name, email.toLowerCase(), cpf, phone, req.user!.id]
      );

      const result = await query(
        `INSERT INTO document_signers (document_id, contact_id, name, email, cpf, phone, signature_type, auth_method, sign_order, message, metadata, access_token)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) RETURNING *`,
        [req.params.id, contactResult.rows[0].id, name, email.toLowerCase(), cpf, phone,
         signature_type || 'assinar', auth_method || 'email_token', sign_order || 0, message, metadata ? JSON.stringify(metadata) : '{}', uuidv4()]
      );

      await createAuditLog({ organization_id: req.user!.organization_id, document_id: req.params.id,
        signer_id: result.rows[0].id, user_id: req.user!.id, action: 'signer_added',
        description: `Signatário ${name} (${email}) adicionado` });

      res.status(201).json(result.rows[0]);
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao adicionar signatário', details: error.message });
    }
  },

  // DELETE /api/documents/:id/signers/:signerId
  async removeSigner(req: AuthRequest, res: Response) {
    try {
      const result = await query(
        `DELETE FROM document_signers WHERE id = $1 AND document_id = $2 RETURNING *`,
        [req.params.signerId, req.params.id]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'Signatário não encontrado' });

      await createAuditLog({ organization_id: req.user!.organization_id, document_id: req.params.id,
        user_id: req.user!.id, action: 'signer_removed', description: `Signatário ${result.rows[0].name} removido` });

      res.json({ message: 'Signatário removido' });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao remover signatário', details: error.message });
    }
  },

  // POST /api/documents/:id/send
  async send(req: AuthRequest, res: Response) {
    try {
      const docResult = await query('SELECT * FROM documents WHERE id = $1 AND organization_id = $2', [req.params.id, req.user!.organization_id]);
      if (docResult.rows.length === 0) return res.status(404).json({ error: 'Documento não encontrado' });

      const doc = docResult.rows[0];
      if (doc.status !== 'draft' && doc.status !== 'pending') return res.status(400).json({ error: 'Documento não pode ser enviado neste status' });

      const signers = await query('SELECT * FROM document_signers WHERE document_id = $1', [req.params.id]);
      if (signers.rows.length === 0) return res.status(400).json({ error: 'Adicione pelo menos um signatário' });

      // Atualizar status
      await query("UPDATE documents SET status = 'in_progress', sent_at = NOW() WHERE id = $1", [req.params.id]);

      // Enviar notificações para signatários
      for (const signer of signers.rows) {
        const accessToken = signer.access_token || uuidv4();
        if (!signer.access_token) {
          await query('UPDATE document_signers SET access_token = $1 WHERE id = $2', [accessToken, signer.id]);
        }
        const signingUrl = `${env.urls.app}/sign/${accessToken}`;

        // Enviar email
        const html = buildSigningEmail(signer.name, doc.name, req.user!.name, signingUrl, doc.message);
        await sendEmail({ to: signer.email, subject: `Documento para assinar: ${doc.name}`, html });

        await query("UPDATE document_signers SET status = 'sent', notified_at = NOW() WHERE id = $1", [signer.id]);

        await createNotification({
          organization_id: req.user!.organization_id, document_id: req.params.id,
          signer_id: signer.id, type: 'email', recipient: signer.email,
          subject: `Documento para assinar: ${doc.name}`, body: html,
        });

        await createAuditLog({ organization_id: req.user!.organization_id, document_id: req.params.id,
          signer_id: signer.id, user_id: req.user!.id, action: 'signer_notified',
          description: `Notificação enviada para ${signer.name} (${signer.email})` });
      }

      await createAuditLog({ organization_id: req.user!.organization_id, document_id: req.params.id,
        user_id: req.user!.id, action: 'document_sent', description: `Documento enviado para ${signers.rows.length} signatário(s)` });

      res.json({ message: `Documento enviado para ${signers.rows.length} signatário(s)`, status: 'in_progress' });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao enviar documento', details: error.message });
    }
  },

  // POST /api/documents/:id/cancel
  async cancel(req: AuthRequest, res: Response) {
    try {
      const { reason } = req.body;
      const result = await query(
        `UPDATE documents SET status = 'cancelled', cancelled_at = NOW(), cancel_reason = $1
         WHERE id = $2 AND organization_id = $3 AND status IN ('pending', 'in_progress') RETURNING *`,
        [reason, req.params.id, req.user!.organization_id]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'Documento não encontrado ou não pode ser cancelado' });

      await query("UPDATE document_signers SET status = 'expired' WHERE document_id = $1 AND status != 'signed'", [req.params.id]);
      await createAuditLog({ organization_id: req.user!.organization_id, document_id: req.params.id,
        user_id: req.user!.id, action: 'document_cancelled', description: `Documento cancelado. Motivo: ${reason || 'Não informado'}` });

      res.json({ message: 'Documento cancelado', document: result.rows[0] });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao cancelar documento', details: error.message });
    }
  },

  // DELETE /api/documents/:id
  async delete(req: AuthRequest, res: Response) {
    try {
      const doc = await query('SELECT * FROM documents WHERE id = $1 AND organization_id = $2', [req.params.id, req.user!.organization_id]);
      if (doc.rows.length === 0) return res.status(404).json({ error: 'Documento não encontrado' });

      if (doc.rows[0].file_key) await deleteFile(doc.rows[0].file_key).catch(() => {});
      if (doc.rows[0].signed_file_key) await deleteFile(doc.rows[0].signed_file_key).catch(() => {});

      await query('DELETE FROM documents WHERE id = $1', [req.params.id]);
      await createAuditLog({ organization_id: req.user!.organization_id, document_id: req.params.id,
        user_id: req.user!.id, action: 'document_deleted', description: `Documento "${doc.rows[0].name}" excluído` });

      res.json({ message: 'Documento excluído' });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao excluir documento', details: error.message });
    }
  },

  // POST /api/documents/:id/fields
  async addField(req: AuthRequest, res: Response) {
    try {
      const { signer_id, field_type, label, page, x, y, width, height, required } = req.body;
      const result = await query(
        `INSERT INTO document_fields (document_id, signer_id, field_type, label, page, x, y, width, height, required)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING *`,
        [req.params.id, signer_id, field_type || 'signature', label, page || 1, x, y, width || 200, height || 50, required !== false]
      );
      res.status(201).json(result.rows[0]);
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao adicionar campo', details: error.message });
    }
  },

  // POST /api/documents/:id/reminder
  async sendReminder(req: AuthRequest, res: Response) {
    try {
      const { signer_id } = req.body;
      const signers = signer_id
        ? await query("SELECT * FROM document_signers WHERE id = $1 AND document_id = $2 AND status IN ('sent','opened')", [signer_id, req.params.id])
        : await query("SELECT * FROM document_signers WHERE document_id = $1 AND status IN ('sent','opened')", [req.params.id]);

      let count = 0;
      for (const signer of signers.rows) {
        const signingUrl = `${env.urls.app}/sign/${signer.access_token}`;
        const { buildReminderEmail } = require('../services/emailService');
        const doc = await query('SELECT name FROM documents WHERE id = $1', [req.params.id]);
        await sendEmail({ to: signer.email, subject: `Lembrete: ${doc.rows[0].name}`, html: buildReminderEmail(signer.name, doc.rows[0].name, signingUrl) });
        await query('UPDATE document_signers SET reminder_count = reminder_count + 1, last_reminder_at = NOW() WHERE id = $1', [signer.id]);
        count++;
      }
      res.json({ message: `Lembrete enviado para ${count} signatário(s)` });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao enviar lembrete', details: error.message });
    }
  },

  // GET /api/documents/:id/download
  async download(req: AuthRequest, res: Response) {
    try {
      const doc = await query('SELECT * FROM documents WHERE id = $1 AND organization_id = $2', [req.params.id, req.user!.organization_id]);
      if (doc.rows.length === 0) return res.status(404).json({ error: 'Documento não encontrado' });

      const key = doc.rows[0].signed_file_key || doc.rows[0].file_key;
      const url = await getFileUrl(key, 3600);

      await createAuditLog({ organization_id: req.user!.organization_id, document_id: req.params.id,
        user_id: req.user!.id, action: 'document_downloaded' });

      res.json({ url, file_name: doc.rows[0].file_name });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao baixar documento', details: error.message });
    }
  },

  // GET /api/documents/stats
  async stats(req: AuthRequest, res: Response) {
    try {
      const statsResult = await query(
        `SELECT
           COUNT(*)::int as total_documents,
           COUNT(*) FILTER (WHERE status = 'draft')::int as draft_documents,
           COUNT(*) FILTER (WHERE status = 'pending')::int as pending_documents,
           COUNT(*) FILTER (WHERE status = 'in_progress')::int as in_progress_documents,
           COUNT(*) FILTER (WHERE status = 'completed')::int as completed_documents,
           COUNT(*) FILTER (WHERE status = 'cancelled')::int as cancelled_documents,
           COUNT(*) FILTER (WHERE status = 'expired')::int as expired_documents
         FROM documents
         WHERE organization_id = $1`,
        [req.user!.organization_id],
      );

      const totals = await query(
        `SELECT
           (SELECT COUNT(*)::int FROM document_signers ds JOIN documents d ON d.id = ds.document_id WHERE d.organization_id = $1) as total_signers,
           (SELECT COUNT(*)::int FROM document_signers ds JOIN documents d ON d.id = ds.document_id WHERE d.organization_id = $1 AND ds.status = 'signed') as total_signed,
           (SELECT COUNT(*)::int FROM contacts WHERE organization_id = $1) as total_contacts,
           (SELECT COUNT(*)::int FROM templates WHERE organization_id = $1) as total_templates,
           (SELECT COUNT(*)::int FROM documents WHERE organization_id = $1 AND DATE_TRUNC('month', created_at) = DATE_TRUNC('month', NOW())) as documents_used_month`,
        [req.user!.organization_id],
      );

      const org = await query('SELECT max_documents_month FROM organizations WHERE id = $1', [req.user!.organization_id]);

      const recent = await query(
        `SELECT d.id, d.name, d.status, d.created_at, d.updated_at,
         (SELECT COUNT(*) FROM document_signers WHERE document_id = d.id) as total_signers,
         (SELECT COUNT(*) FROM document_signers WHERE document_id = d.id AND status = 'signed') as signed_count
         FROM documents d WHERE d.organization_id = $1 ORDER BY d.updated_at DESC LIMIT 10`,
        [req.user!.organization_id]
      );

      const stats = {
        ...(statsResult.rows[0] || {}),
        ...(totals.rows[0] || {}),
        max_documents_month: org.rows[0]?.max_documents_month || 0,
      };

      res.json({ stats, recent_documents: recent.rows });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao buscar estatísticas', details: error.message });
    }
  },
};
