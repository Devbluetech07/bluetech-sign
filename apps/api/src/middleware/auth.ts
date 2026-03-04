import { Request, Response, NextFunction } from 'express';
import jwt, { SignOptions } from 'jsonwebtoken';
import { query } from '../config/database';
import { env } from '../config/env';

const JWT_SECRET = env.jwt.secret;

export interface AuthRequest extends Request {
  user?: {
    id: string;
    organization_id: string;
    name: string;
    email: string;
    role: string;
    permissions: Record<string, boolean>;
  };
}

export function authMiddleware(req: AuthRequest, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) {
    return res.status(401).json({ error: 'Token de acesso não fornecido' });
  }
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as AuthRequest['user'];
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Token inválido ou expirado' });
  }
}

export function authOrApiKeyMiddleware(req: AuthRequest, res: Response, next: NextFunction) {
  if (req.user) return next();
  return authMiddleware(req, res, next);
}

export function requireRole(...roles: string[]) {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.user) return res.status(401).json({ error: 'Não autenticado' });
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Sem permissão para esta ação' });
    }
    next();
  };
}

export function requirePermission(permission: string) {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.user) return res.status(401).json({ error: 'Não autenticado' });
    if (req.user.role === 'admin') return next();
    if (!req.user.permissions?.[permission]) {
      return res.status(403).json({ error: `Permissão '${permission}' necessária` });
    }
    next();
  };
}

interface TokenUser {
  id: string;
  organization_id: string;
  name: string;
  email: string;
  role: string;
  permissions: Record<string, boolean>;
}

export function generateToken(user: TokenUser): string {
  const expiresIn = env.jwt.expiresIn as SignOptions['expiresIn'];
  return jwt.sign(
    {
      id: user.id,
      organization_id: user.organization_id,
      name: user.name,
      email: user.email,
      role: user.role,
      permissions: user.permissions,
    },
    JWT_SECRET,
    { expiresIn }
  );
}

export function generateSignerToken(signerId: string, documentId: string): string {
  return jwt.sign({ signerId, documentId, type: 'signer' }, JWT_SECRET, { expiresIn: '30d' });
}

// API Key middleware
export async function apiKeyMiddleware(req: AuthRequest, res: Response, next: NextFunction) {
  const apiKey = req.headers['x-api-key'] as string;
  if (!apiKey) return next();

  try {
    const prefix = apiKey.substring(0, 8);
    const result = await query('SELECT ak.*, o.id as org_id FROM api_keys ak JOIN organizations o ON o.id = ak.organization_id WHERE ak.key_prefix = $1 AND ak.active = true', [prefix]);

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'API Key inválida' });
    }

    const bcrypt = require('bcrypt');
    const isValid = await bcrypt.compare(apiKey, result.rows[0].key_hash);
    if (!isValid) return res.status(401).json({ error: 'API Key inválida' });

    await query('UPDATE api_keys SET last_used_at = NOW() WHERE id = $1', [result.rows[0].id]);

    req.user = {
      id: 'api-key',
      organization_id: result.rows[0].organization_id,
      name: 'API Key: ' + result.rows[0].name,
      email: '',
      role: 'operator',
      permissions: { documents: true, templates: true, contacts: true, reports: false, settings: false, api_keys: false },
    };
    next();
  } catch (error) {
    return res.status(500).json({ error: 'Erro ao validar API Key' });
  }
}
