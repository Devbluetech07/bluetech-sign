import { Response } from 'express';
import { query } from '../config/database';
import { AuthRequest } from '../middleware/auth';
import { uploadFile, getFileUrl, deleteFile } from '../config/minio';
import { createAuditLog } from '../services/auditService';
import { v4 as uuidv4 } from 'uuid';
import bcrypt from 'bcrypt';

// ============ TEMPLATES ============
export const templatesController = {
  async list(req: AuthRequest, res: Response) {
    try {
      const { status, search, category } = req.query;
      let sql = 'SELECT * FROM templates WHERE organization_id = $1';
      const params: any[] = [req.user!.organization_id];
      let idx = 2;
      if (status) { sql += ` AND status = $${idx++}`; params.push(status); }
      if (category) { sql += ` AND category = $${idx++}`; params.push(category); }
      if (search) { sql += ` AND name ILIKE $${idx++}`; params.push(`%${search}%`); }
      sql += ' ORDER BY created_at DESC';
      const result = await query(sql, params);
      res.json(result.rows);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async getById(req: AuthRequest, res: Response) {
    try {
      const result = await query('SELECT * FROM templates WHERE id = $1 AND organization_id = $2', [req.params.id, req.user!.organization_id]);
      if (result.rows.length === 0) return res.status(404).json({ error: 'Template não encontrado' });
      const t = result.rows[0];
      if (t.file_key) t.file_url = await getFileUrl(t.file_key);
      res.json(t);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async create(req: AuthRequest, res: Response) {
    try {
      const { name, description, category, signer_roles, default_message, default_auth_methods, fields } = req.body;
      let fileKey = null, fileName = null, fileSize = null;
      if (req.file) {
        const ext = req.file.originalname.split('.').pop();
        fileKey = `templates/${req.user!.organization_id}/${uuidv4()}.${ext}`;
        await uploadFile(fileKey, req.file.buffer, req.file.mimetype);
        fileName = req.file.originalname;
        fileSize = req.file.size;
      }
      const result = await query(
        `INSERT INTO templates (organization_id, name, description, category, file_key, file_name, file_size, signer_roles, default_message, default_auth_methods, fields, created_by)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
        [req.user!.organization_id, name, description, category, fileKey, fileName, fileSize,
         signer_roles ? JSON.stringify(signer_roles) : '[]', default_message,
         Array.isArray(default_auth_methods) ? `{${default_auth_methods.join(',')}}` : '{email_token}',
         fields ? JSON.stringify(fields) : '[]', req.user!.id]
      );
      await createAuditLog({ organization_id: req.user!.organization_id, user_id: req.user!.id, action: 'template_created', description: `Template "${name}" criado` });
      res.status(201).json(result.rows[0]);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async update(req: AuthRequest, res: Response) {
    try {
      const { name, description, category, status, signer_roles, default_message, fields } = req.body;
      const result = await query(
        `UPDATE templates SET name=COALESCE($1,name), description=COALESCE($2,description), category=COALESCE($3,category),
         status=COALESCE($4,status), signer_roles=COALESCE($5,signer_roles), default_message=COALESCE($6,default_message), fields=COALESCE($7,fields)
         WHERE id=$8 AND organization_id=$9 RETURNING *`,
        [name, description, category, status, signer_roles ? JSON.stringify(signer_roles) : null,
         default_message, fields ? JSON.stringify(fields) : null, req.params.id, req.user!.organization_id]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'Template não encontrado' });
      res.json(result.rows[0]);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async delete(req: AuthRequest, res: Response) {
    try {
      const t = await query('SELECT * FROM templates WHERE id=$1 AND organization_id=$2', [req.params.id, req.user!.organization_id]);
      if (t.rows.length === 0) return res.status(404).json({ error: 'Template não encontrado' });
      if (t.rows[0].file_key) await deleteFile(t.rows[0].file_key).catch(() => {});
      await query('DELETE FROM templates WHERE id=$1', [req.params.id]);
      res.json({ message: 'Template excluído' });
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
};

// ============ FOLDERS ============
export const foldersController = {
  async list(req: AuthRequest, res: Response) {
    try {
      const result = await query(
        `SELECT f.*, (SELECT COUNT(*) FROM documents WHERE folder_id = f.id) as doc_count
         FROM folders f WHERE f.organization_id = $1 ORDER BY f.name`, [req.user!.organization_id]);
      res.json(result.rows);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async create(req: AuthRequest, res: Response) {
    try {
      const { name, color, icon, description, parent_id } = req.body;
      const result = await query(
        'INSERT INTO folders (organization_id, name, color, icon, description, parent_id, created_by) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *',
        [req.user!.organization_id, name, color || '#6366F1', icon || 'folder', description, parent_id, req.user!.id]
      );
      res.status(201).json(result.rows[0]);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async update(req: AuthRequest, res: Response) {
    try {
      const { name, color, icon, description } = req.body;
      const result = await query(
        'UPDATE folders SET name=COALESCE($1,name), color=COALESCE($2,color), icon=COALESCE($3,icon), description=COALESCE($4,description) WHERE id=$5 AND organization_id=$6 RETURNING *',
        [name, color, icon, description, req.params.id, req.user!.organization_id]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'Pasta não encontrada' });
      res.json(result.rows[0]);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async delete(req: AuthRequest, res: Response) {
    try {
      await query("UPDATE documents SET folder_id = NULL WHERE folder_id = $1", [req.params.id]);
      await query('DELETE FROM folders WHERE id=$1 AND organization_id=$2', [req.params.id, req.user!.organization_id]);
      res.json({ message: 'Pasta excluída' });
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
};

// ============ CONTACTS ============
export const contactsController = {
  async list(req: AuthRequest, res: Response) {
    try {
      const { search, page = 1, limit = 50 } = req.query;
      let sql = 'SELECT * FROM contacts WHERE organization_id = $1';
      const params: any[] = [req.user!.organization_id];
      let idx = 2;
      if (search) { sql += ` AND (name ILIKE $${idx} OR email ILIKE $${idx} OR cpf ILIKE $${idx})`; params.push(`%${search}%`); idx++; }
      const countResult = await query(sql.replace('SELECT *', 'SELECT COUNT(*) as total'), params);
      sql += ` ORDER BY name ASC LIMIT $${idx++} OFFSET $${idx++}`;
      params.push(Number(limit), (Number(page) - 1) * Number(limit));
      const result = await query(sql, params);
      res.json({ contacts: result.rows, total: parseInt(countResult.rows[0]?.total || '0') });
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async create(req: AuthRequest, res: Response) {
    try {
      const { name, email, cpf, phone, company, position, notes, tags } = req.body;
      const result = await query(
        `INSERT INTO contacts (organization_id, name, email, cpf, phone, company, position, notes, tags, created_by)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
        [req.user!.organization_id, name, email?.toLowerCase(), cpf, phone, company, position, notes, tags || [], req.user!.id]
      );
      res.status(201).json(result.rows[0]);
    } catch (e: any) {
      if (e.constraint) return res.status(409).json({ error: 'Contato com este email já existe' });
      res.status(500).json({ error: e.message });
    }
  },
  async update(req: AuthRequest, res: Response) {
    try {
      const { name, email, cpf, phone, company, position, notes, tags } = req.body;
      const result = await query(
        `UPDATE contacts SET name=COALESCE($1,name), email=COALESCE($2,email), cpf=COALESCE($3,cpf),
         phone=COALESCE($4,phone), company=COALESCE($5,company), position=COALESCE($6,position),
         notes=COALESCE($7,notes), tags=COALESCE($8,tags)
         WHERE id=$9 AND organization_id=$10 RETURNING *`,
        [name, email?.toLowerCase(), cpf, phone, company, position, notes, tags, req.params.id, req.user!.organization_id]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'Contato não encontrado' });
      res.json(result.rows[0]);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async delete(req: AuthRequest, res: Response) {
    try {
      await query('DELETE FROM contacts WHERE id=$1 AND organization_id=$2', [req.params.id, req.user!.organization_id]);
      res.json({ message: 'Contato excluído' });
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
};

// ============ USERS ============
export const usersController = {
  async list(req: AuthRequest, res: Response) {
    try {
      const result = await query(
        'SELECT id, name, email, cpf, phone, role, status, avatar_url, permissions, last_login_at, created_at FROM users WHERE organization_id = $1 ORDER BY name',
        [req.user!.organization_id]
      );
      res.json(result.rows);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async create(req: AuthRequest, res: Response) {
    try {
      const { name, email, password, cpf, phone, role, permissions } = req.body;
      const hash = await bcrypt.hash(password || 'Mudar@123', 12);
      const result = await query(
        `INSERT INTO users (organization_id, name, email, password_hash, cpf, phone, role, status, email_verified, permissions)
         VALUES ($1,$2,$3,$4,$5,$6,$7,'active',true,$8) RETURNING id,name,email,cpf,phone,role,status,permissions,created_at`,
        [req.user!.organization_id, name, email.toLowerCase(), hash, cpf, phone, role || 'operator', JSON.stringify(permissions || {})]
      );
      res.status(201).json(result.rows[0]);
    } catch (e: any) {
      if (e.constraint) return res.status(409).json({ error: 'Email já cadastrado' });
      res.status(500).json({ error: e.message });
    }
  },
  async update(req: AuthRequest, res: Response) {
    try {
      const { name, phone, role, status, permissions } = req.body;
      const result = await query(
        `UPDATE users SET name=COALESCE($1,name), phone=COALESCE($2,phone), role=COALESCE($3,role),
         status=COALESCE($4,status), permissions=COALESCE($5,permissions)
         WHERE id=$6 AND organization_id=$7 RETURNING id,name,email,phone,role,status,permissions`,
        [name, phone, role, status, permissions ? JSON.stringify(permissions) : null, req.params.id, req.user!.organization_id]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'Usuário não encontrado' });
      res.json(result.rows[0]);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async delete(req: AuthRequest, res: Response) {
    try {
      if (req.params.id === req.user!.id) return res.status(400).json({ error: 'Não é possível excluir seu próprio usuário' });
      await query("UPDATE users SET status='inactive' WHERE id=$1 AND organization_id=$2", [req.params.id, req.user!.organization_id]);
      res.json({ message: 'Usuário desativado' });
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
};

// ============ WEBHOOKS ============
export const webhooksController = {
  async list(req: AuthRequest, res: Response) {
    try {
      const result = await query('SELECT * FROM webhooks WHERE organization_id = $1 ORDER BY created_at DESC', [req.user!.organization_id]);
      res.json(result.rows);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async create(req: AuthRequest, res: Response) {
    try {
      const { url, events } = req.body;
      if (!url) return res.status(400).json({ error: 'URL é obrigatória' });
      const eventArray = Array.isArray(events) ? events : [];
      const result = await query(
        'INSERT INTO webhooks (organization_id, url, events, created_by) VALUES ($1,$2,$3,$4) RETURNING *',
        [req.user!.organization_id, url, `{${eventArray.join(',')}}`, req.user!.id]
      );
      res.status(201).json(result.rows[0]);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async delete(req: AuthRequest, res: Response) {
    try {
      await query('DELETE FROM webhooks WHERE id=$1 AND organization_id=$2', [req.params.id, req.user!.organization_id]);
      res.json({ message: 'Webhook excluído' });
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
};

// ============ SETTINGS ============
export const settingsController = {
  async getOrganization(req: AuthRequest, res: Response) {
    try {
      const result = await query('SELECT * FROM organizations WHERE id = $1', [req.user!.organization_id]);
      const settings = await query('SELECT * FROM system_settings WHERE organization_id = $1', [req.user!.organization_id]);
      res.json({ organization: result.rows[0], settings: settings.rows });
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async updateOrganization(req: AuthRequest, res: Response) {
    try {
      const { name, cnpj, email, phone, brand_primary_color, brand_secondary_color, brand_accent_color,
        custom_email_header, custom_email_footer, platform_name, visual_preset, logo_url } = req.body;
      const result = await query(
        `UPDATE organizations SET
         name=COALESCE($1,name), cnpj=COALESCE($2,cnpj), email=COALESCE($3,email),
         phone=COALESCE($4,phone), brand_primary_color=COALESCE($5,brand_primary_color),
         brand_secondary_color=COALESCE($6,brand_secondary_color), brand_accent_color=COALESCE($7,brand_accent_color),
         custom_email_header=COALESCE($8,custom_email_header), custom_email_footer=COALESCE($9,custom_email_footer),
         platform_name=COALESCE($10,platform_name), visual_preset=COALESCE($11,visual_preset),
         logo_url=COALESCE($12,logo_url)
         WHERE id=$13 RETURNING *`,
        [name, cnpj, email, phone, brand_primary_color, brand_secondary_color, brand_accent_color,
         custom_email_header, custom_email_footer, platform_name, visual_preset, logo_url, req.user!.organization_id]
      );
      res.json(result.rows[0]);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async updateSetting(req: AuthRequest, res: Response) {
    try {
      const { key, value } = req.body;
      const jsonValue = typeof value === 'string' ? JSON.stringify(value) : JSON.stringify(value);
      await query(
        `INSERT INTO system_settings (organization_id, key, value) VALUES ($1,$2,$3::jsonb)
         ON CONFLICT (organization_id, key) DO UPDATE SET value=$3::jsonb, updated_at=NOW()`,
        [req.user!.organization_id, key, jsonValue]
      );
      res.json({ message: 'Configuração atualizada' });
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async uploadLogo(req: AuthRequest, res: Response) {
    try {
      if (!req.file) return res.status(400).json({ error: 'Imagem é obrigatória' });
      const key = `logos/${req.user!.organization_id}/logo.${req.file.originalname.split('.').pop()}`;
      await uploadFile(key, req.file.buffer, req.file.mimetype);
      const url = await getFileUrl(key, 86400 * 365);
      await query('UPDATE organizations SET logo_url = $1 WHERE id = $2', [url, req.user!.organization_id]);
      res.json({ logo_url: url });
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async listApiKeys(req: AuthRequest, res: Response) {
    try {
      const result = await query(
        `SELECT id, name, key_prefix, scopes, active, last_used_at, created_at
         FROM api_keys
         WHERE organization_id = $1
         ORDER BY created_at DESC`,
        [req.user!.organization_id],
      );
      res.json(result.rows);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async createApiKey(req: AuthRequest, res: Response) {
    try {
      const name = String(req.body.name || '').trim();
      const scopes = Array.isArray(req.body.scopes) ? req.body.scopes : ['documents'];
      if (!name) return res.status(400).json({ error: 'Nome da chave e obrigatorio' });

      const crypto = require('crypto');
      const key = 'bt_' + crypto.randomBytes(32).toString('hex');
      const prefix = key.substring(0, 8);
      const hash = await bcrypt.hash(key, 10);

      const result = await query(
        `INSERT INTO api_keys (organization_id, name, key_prefix, key_hash, scopes, active, created_by)
         VALUES ($1, $2, $3, $4, $5, true, $6)
         RETURNING id, name, key_prefix, scopes, active, created_at`,
        [req.user!.organization_id, name, prefix, hash, scopes, req.user!.id],
      );
      res.status(201).json({ ...result.rows[0], key });
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async revokeApiKey(req: AuthRequest, res: Response) {
    try {
      const result = await query(
        `UPDATE api_keys SET active = false WHERE id = $1 AND organization_id = $2 RETURNING id`,
        [req.params.id, req.user!.organization_id],
      );
      if (!result.rows.length) return res.status(404).json({ error: 'Chave nao encontrada' });
      res.json({ message: 'Chave revogada' });
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
};

// ============ TAGS ============
export const tagsController = {
  async list(req: AuthRequest, res: Response) {
    try {
      const result = await query('SELECT * FROM tags WHERE organization_id = $1 ORDER BY name', [req.user!.organization_id]);
      res.json(result.rows);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async create(req: AuthRequest, res: Response) {
    try {
      const { name, color } = req.body;
      const result = await query('INSERT INTO tags (organization_id, name, color) VALUES ($1,$2,$3) RETURNING *', [req.user!.organization_id, name, color || '#6366F1']);
      res.status(201).json(result.rows[0]);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async delete(req: AuthRequest, res: Response) {
    try {
      await query('DELETE FROM tags WHERE id=$1 AND organization_id=$2', [req.params.id, req.user!.organization_id]);
      res.json({ message: 'Tag excluída' });
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
};

// ============ REPORTS ============
export const reportsController = {
  async documentsByStatus(req: AuthRequest, res: Response) {
    try {
      const result = await query(
        `SELECT status, COUNT(*) as count FROM documents WHERE organization_id = $1
         AND created_at >= COALESCE($2, NOW() - INTERVAL '30 days') AND created_at <= COALESCE($3, NOW())
         GROUP BY status`, [req.user!.organization_id, req.query.start_date, req.query.end_date]);
      res.json(result.rows);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async signatureTimeline(req: AuthRequest, res: Response) {
    try {
      const result = await query(
        `SELECT DATE(ds.signed_at) as date, COUNT(*) as count FROM document_signers ds
         JOIN documents d ON d.id = ds.document_id WHERE d.organization_id = $1 AND ds.signed_at IS NOT NULL
         AND ds.signed_at >= NOW() - INTERVAL '30 days' GROUP BY DATE(ds.signed_at) ORDER BY date`,
        [req.user!.organization_id]);
      res.json(result.rows);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async auditReport(req: AuthRequest, res: Response) {
    try {
      const { getAuditLogs } = require('../services/auditService');
      const logs = await getAuditLogs(req.user!.organization_id, req.query);
      res.json(logs);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
  async notificationsReport(req: AuthRequest, res: Response) {
    try {
      const result = await query(
        `SELECT n.*, d.name as document_name FROM notifications n
         LEFT JOIN documents d ON d.id = n.document_id
         WHERE n.organization_id = $1 ORDER BY n.created_at DESC LIMIT 100`,
        [req.user!.organization_id]);
      res.json(result.rows);
    } catch (e: any) { res.status(500).json({ error: e.message }); }
  },
};
