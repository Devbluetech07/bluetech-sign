import { Request, Response } from 'express';
import bcrypt from 'bcrypt';
import { query } from '../config/database';
import { generateToken, AuthRequest } from '../middleware/auth';
import { createAuditLog } from '../services/auditService';
import crypto from 'crypto';

export const authController = {
  // POST /api/auth/login
  async login(req: Request, res: Response) {
    try {
      const { email, password } = req.body;
      if (!email || !password) return res.status(400).json({ error: 'Email e senha são obrigatórios' });

      const result = await query(
        `SELECT u.*, o.name as org_name, o.brand_primary_color, o.logo_url
         FROM users u JOIN organizations o ON o.id = u.organization_id
         WHERE u.email = $1 AND u.status = 'active'`, [email.toLowerCase()]
      );

      if (result.rows.length === 0) return res.status(401).json({ error: 'Email ou senha incorretos' });

      const user = result.rows[0];
      const validPassword = await bcrypt.compare(password, user.password_hash);
      if (!validPassword) return res.status(401).json({ error: 'Email ou senha incorretos' });

      await query('UPDATE users SET last_login_at = NOW(), last_login_ip = $1 WHERE id = $2', [req.ip, user.id]);

      const token = generateToken(user);
      await createAuditLog({ organization_id: user.organization_id, user_id: user.id, action: 'user_login', ip_address: req.ip, user_agent: req.headers['user-agent'] });

      res.json({
        token,
        user: {
          id: user.id, organization_id: user.organization_id, name: user.name, email: user.email,
          cpf: user.cpf, phone: user.phone, avatar_url: user.avatar_url, role: user.role,
          permissions: user.permissions, org_name: user.org_name, brand_primary_color: user.brand_primary_color,
          logo_url: user.logo_url,
        },
      });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro interno', details: error.message });
    }
  },

  // POST /api/auth/register
  async register(req: Request, res: Response) {
    try {
      const { name, email, password, cpf, phone, organization_name } = req.body;
      if (!name || !email || !password) return res.status(400).json({ error: 'Nome, email e senha são obrigatórios' });

      const exists = await query('SELECT id FROM users WHERE email = $1', [email.toLowerCase()]);
      if (exists.rows.length > 0) return res.status(409).json({ error: 'Email já cadastrado' });

      const password_hash = await bcrypt.hash(password, 12);
      const slug = (organization_name || name).toLowerCase().replace(/[^a-z0-9]/g, '-').substring(0, 50);

      const orgResult = await query(
        `INSERT INTO organizations (name, slug, email) VALUES ($1, $2, $3) RETURNING id`,
        [organization_name || `Org de ${name}`, slug + '-' + Date.now(), email.toLowerCase()]
      );

      const userResult = await query(
        `INSERT INTO users (organization_id, name, email, password_hash, cpf, phone, role, status, email_verified, permissions)
         VALUES ($1, $2, $3, $4, $5, $6, 'admin', 'active', true, $7) RETURNING *`,
        [orgResult.rows[0].id, name, email.toLowerCase(), password_hash, cpf, phone,
         JSON.stringify({ documents: true, templates: true, contacts: true, reports: true, settings: true, api_keys: true })]
      );

      const user = userResult.rows[0];
      const token = generateToken({ ...user, organization_id: orgResult.rows[0].id });

      res.status(201).json({ token, user: { id: user.id, organization_id: orgResult.rows[0].id, name: user.name, email: user.email, role: user.role } });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao registrar', details: error.message });
    }
  },

  // GET /api/auth/me
  async me(req: AuthRequest, res: Response) {
    try {
      const result = await query(
        `SELECT u.*, o.name as org_name, o.brand_primary_color, o.brand_secondary_color, o.logo_url, o.plan, o.max_documents_month, o.documents_used_month
         FROM users u JOIN organizations o ON o.id = u.organization_id WHERE u.id = $1`, [req.user!.id]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'Usuário não encontrado' });
      const { password_hash, two_factor_secret, ...user } = result.rows[0];
      res.json(user);
    } catch (error: any) {
      res.status(500).json({ error: 'Erro interno', details: error.message });
    }
  },

  // PUT /api/auth/profile
  async updateProfile(req: AuthRequest, res: Response) {
    try {
      const { name, phone, avatar_url } = req.body;
      const result = await query(
        'UPDATE users SET name = COALESCE($1, name), phone = COALESCE($2, phone), avatar_url = COALESCE($3, avatar_url) WHERE id = $4 RETURNING id, name, email, phone, avatar_url',
        [name, phone, avatar_url, req.user!.id]
      );
      res.json(result.rows[0]);
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao atualizar perfil', details: error.message });
    }
  },

  // PUT /api/auth/password
  async changePassword(req: AuthRequest, res: Response) {
    try {
      const { current_password, new_password } = req.body;
      const result = await query('SELECT password_hash FROM users WHERE id = $1', [req.user!.id]);
      const valid = await bcrypt.compare(current_password, result.rows[0].password_hash);
      if (!valid) return res.status(400).json({ error: 'Senha atual incorreta' });

      const hash = await bcrypt.hash(new_password, 12);
      await query('UPDATE users SET password_hash = $1 WHERE id = $2', [hash, req.user!.id]);
      res.json({ message: 'Senha alterada com sucesso' });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao alterar senha', details: error.message });
    }
  },
};
