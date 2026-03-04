import { query } from '../config/database';

interface AuditEntry {
  organization_id: string;
  document_id?: string;
  signer_id?: string;
  user_id?: string;
  action: string;
  description?: string;
  ip_address?: string;
  user_agent?: string;
  geolocation?: any;
  metadata?: any;
}

export async function createAuditLog(entry: AuditEntry) {
  try {
    await query(
      `INSERT INTO audit_logs (organization_id, document_id, signer_id, user_id, action, description, ip_address, user_agent, geolocation, metadata)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [
        entry.organization_id, entry.document_id || null, entry.signer_id || null,
        entry.user_id || null, entry.action, entry.description || null,
        entry.ip_address || null, entry.user_agent || null,
        entry.geolocation ? JSON.stringify(entry.geolocation) : null,
        entry.metadata ? JSON.stringify(entry.metadata) : '{}',
      ]
    );
  } catch (error) {
    console.error('Erro ao criar audit log:', error);
  }
}

export async function getAuditLogs(organizationId: string, filters: any = {}) {
  let sql = `SELECT al.*, d.name as document_name, u.name as user_name
    FROM audit_logs al
    LEFT JOIN documents d ON d.id = al.document_id
    LEFT JOIN users u ON u.id = al.user_id
    WHERE al.organization_id = $1`;
  const params: any[] = [organizationId];
  let paramIndex = 2;

  if (filters.document_id) {
    sql += ` AND al.document_id = $${paramIndex++}`;
    params.push(filters.document_id);
  }
  if (filters.action) {
    sql += ` AND al.action = $${paramIndex++}`;
    params.push(filters.action);
  }
  if (filters.start_date) {
    sql += ` AND al.created_at >= $${paramIndex++}`;
    params.push(filters.start_date);
  }
  if (filters.end_date) {
    sql += ` AND al.created_at <= $${paramIndex++}`;
    params.push(filters.end_date);
  }

  sql += ` ORDER BY al.created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex++}`;
  params.push(filters.limit || 50, filters.offset || 0);

  const result = await query(sql, params);
  return result.rows;
}

export async function getDocumentAuditLog(documentId: string) {
  const result = await query(
    `SELECT al.*, u.name as user_name, ds.name as signer_name
     FROM audit_logs al
     LEFT JOIN users u ON u.id = al.user_id
     LEFT JOIN document_signers ds ON ds.id = al.signer_id
     WHERE al.document_id = $1
     ORDER BY al.created_at ASC`,
    [documentId]
  );
  return result.rows;
}
