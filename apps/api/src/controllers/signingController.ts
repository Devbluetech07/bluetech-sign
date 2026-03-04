import { Request, Response } from 'express';
import crypto from 'crypto';
import { query } from '../config/database';
import { getFileUrl, uploadFile } from '../config/minio';
import { createAuditLog } from '../services/auditService';
import { sendEmail, buildTokenEmail } from '../services/emailService';
import * as biometriaService from '../services/biometriaService';
import { v4 as uuidv4 } from 'uuid';

export const signingController = {
  // GET /api/signing/:token - Acessar documento para assinar (público)
  async getDocument(req: Request, res: Response) {
    try {
      const { token } = req.params;
      const signer = await query(
        `SELECT ds.*, d.name as document_name, d.file_key, d.status as document_status,
         d.message as document_message, d.organization_id, d.file_pages,
         o.name as org_name, o.brand_primary_color, o.brand_secondary_color, o.logo_url
         FROM document_signers ds
         JOIN documents d ON d.id = ds.document_id
         JOIN organizations o ON o.id = d.organization_id
         WHERE ds.access_token = $1`,
        [token]
      );

      if (signer.rows.length === 0) return res.status(404).json({ error: 'Link de assinatura inválido ou expirado' });

      const s = signer.rows[0];
      if (s.document_status === 'cancelled') return res.status(410).json({ error: 'Este documento foi cancelado' });
      if (s.document_status === 'expired') return res.status(410).json({ error: 'Este documento expirou' });
      if (s.status === 'signed') return res.status(200).json({ already_signed: true, signed_at: s.signed_at, message: 'Você já assinou este documento' });

      // Marcar como aberto
      if (!s.opened_at) {
        await query("UPDATE document_signers SET opened_at = NOW(), status = 'opened' WHERE id = $1", [s.id]);
        await createAuditLog({ organization_id: s.organization_id, document_id: s.document_id,
          signer_id: s.id, action: 'signer_opened', description: `${s.name} abriu o documento`,
          ip_address: req.ip, user_agent: req.headers['user-agent'] as string });
      }

      // Gerar URL temporária do arquivo
      const fileUrl = await getFileUrl(s.file_key, 3600);

      // Buscar campos para este signatário
      const fields = await query('SELECT * FROM document_fields WHERE document_id = $1 AND signer_id = $2', [s.document_id, s.id]);

      // Buscar todos signatários (para mostrar progresso)
      const allSigners = await query(
        `SELECT name, email, status, signature_type, sign_order, signed_at FROM document_signers WHERE document_id = $1 ORDER BY sign_order ASC`,
        [s.document_id]
      );

      res.json({
        signer: {
          id: s.id,
          name: s.name,
          email: s.email,
          cpf: s.cpf,
          signature_type: s.signature_type,
          auth_method: s.auth_method,
          status: s.status,
          metadata: s.metadata || {},
        },
        document: { name: s.document_name, file_url: fileUrl, pages: s.file_pages, message: s.document_message },
        organization: { name: s.org_name, primary_color: s.brand_primary_color, secondary_color: s.brand_secondary_color, logo_url: s.logo_url },
        fields: fields.rows,
        signers: allSigners.rows.map((sg: any) => ({ name: sg.name, status: sg.status, signature_type: sg.signature_type, signed_at: sg.signed_at })),
      });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao acessar documento', details: error.message });
    }
  },

  // POST /api/signing/:token/request-token - Solicitar token de verificação
  async requestToken(req: Request, res: Response) {
    try {
      const signer = await query(
        `SELECT ds.*, d.name as doc_name, o.brand_primary_color FROM document_signers ds
         JOIN documents d ON d.id = ds.document_id JOIN organizations o ON o.id = d.organization_id
         WHERE ds.access_token = $1 AND ds.status IN ('sent', 'opened')`, [req.params.token]
      );
      if (signer.rows.length === 0) return res.status(404).json({ error: 'Signatário não encontrado' });

      const s = signer.rows[0];
      const token = Math.random().toString().substring(2, 8);
      await query("UPDATE document_signers SET sign_token = $1, sign_token_expires_at = NOW() + INTERVAL '10 minutes' WHERE id = $2", [token, s.id]);

      if (s.auth_method === 'email_token') {
        const html = buildTokenEmail(s.name, token, s.brand_primary_color);
        await sendEmail({ to: s.email, subject: `Código de verificação - ${s.doc_name}`, html });
      }

      res.json({ message: 'Token enviado', method: s.auth_method });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao enviar token', details: error.message });
    }
  },

  // POST /api/signing/:token/verify-token - Verificar token
  async verifyToken(req: Request, res: Response) {
    try {
      const { code } = req.body;
      const signer = await query(
        `SELECT * FROM document_signers WHERE access_token = $1 AND sign_token = $2 AND sign_token_expires_at > NOW()`,
        [req.params.token, code]
      );
      if (signer.rows.length === 0) return res.status(400).json({ error: 'Código inválido ou expirado' });
      res.json({ verified: true });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro na verificação', details: error.message });
    }
  },

  // POST /api/signing/:token/verify-biometria - Verificação biométrica
  async verifyBiometria(req: Request, res: Response) {
    try {
      const { image } = req.body;
      if (!image) return res.status(400).json({ error: 'Imagem é obrigatória' });

      const signer = await query(
        `SELECT ds.*, c.biometria_external_id, d.organization_id FROM document_signers ds
         LEFT JOIN contacts c ON c.id = ds.contact_id
         JOIN documents d ON d.id = ds.document_id
         WHERE ds.access_token = $1`, [req.params.token]
      );
      if (signer.rows.length === 0) return res.status(404).json({ error: 'Signatário não encontrado' });

      const s = signer.rows[0];

      // Salvar foto da biometria no MinIO
      const imageBuffer = Buffer.from(image.replace(/^data:image\/\w+;base64,/, ''), 'base64');
      const photoKey = `biometria/${s.document_id}/${s.id}_${Date.now()}.jpg`;
      await uploadFile(photoKey, imageBuffer, 'image/jpeg');

      let result;
      if (s.biometria_external_id && biometriaService.isConfigured()) {
        result = await biometriaService.verificarFace(image, s.biometria_external_id);
      } else if (biometriaService.isConfigured()) {
        // Cadastrar e verificar
        const externalId = `signer_${s.id}`;
        await biometriaService.cadastrarFace(image, externalId, s.name, s.cpf);
        result = { success: true, verified: true, score: 100, message: 'Face cadastrada e verificada' };
        await query('UPDATE contacts SET has_biometria = true, biometria_external_id = $1 WHERE id = $2', [externalId, s.contact_id]);
      } else {
        result = { success: true, verified: true, score: 100, message: 'Biometria registrada (API não configurada - modo simulação)' };
      }

      await query('UPDATE document_signers SET biometria_verified = $1, biometria_score = $2, biometria_photo_key = $3 WHERE id = $4',
        [result.verified, result.score, photoKey, s.id]);

      await createAuditLog({ organization_id: s.organization_id, document_id: s.document_id, signer_id: s.id,
        action: result.verified ? 'biometria_verificada' : 'biometria_falhou',
        description: `Biometria de ${s.name}: ${result.message}`, ip_address: req.ip,
        metadata: { score: result.score, verified: result.verified } });

      res.json({ verified: result.verified, score: result.score, message: result.message });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro na verificação biométrica', details: error.message });
    }
  },

  // POST /api/signing/:token/sign - Efetuar assinatura
  async sign(req: Request, res: Response) {
    try {
      const { signature_data, token_code, fields_data } = req.body;

      const signer = await query(
        `SELECT ds.*, d.organization_id, d.name as doc_name, d.id as doc_id FROM document_signers ds
         JOIN documents d ON d.id = ds.document_id
         WHERE ds.access_token = $1 AND ds.status IN ('sent', 'opened')`, [req.params.token]
      );
      if (signer.rows.length === 0) return res.status(404).json({ error: 'Assinatura não disponível' });

      const s = signer.rows[0];

      // Verificar token se necessário
      if (s.auth_method === 'email_token' || s.auth_method === 'sms_token') {
        if (!token_code) return res.status(400).json({ error: 'Código de verificação é obrigatório' });
        const tokenValid = await query(
          'SELECT id FROM document_signers WHERE id = $1 AND sign_token = $2 AND sign_token_expires_at > NOW()', [s.id, token_code]
        );
        if (tokenValid.rows.length === 0) return res.status(400).json({ error: 'Código inválido ou expirado' });
      }

      // Verificar biometria se necessário
      if (s.auth_method === 'biometria_facial' && !s.biometria_verified) {
        return res.status(400).json({ error: 'Verificação biométrica necessária antes de assinar' });
      }

      // Salvar imagem da assinatura se fornecida
      let signatureImageKey = null;
      if (signature_data?.image) {
        const imgBuffer = Buffer.from(signature_data.image.replace(/^data:image\/\w+;base64,/, ''), 'base64');
        signatureImageKey = `signatures/${s.doc_id}/${s.id}_signature.png`;
        await uploadFile(signatureImageKey, imgBuffer, 'image/png');
      }

      // Salvar valores dos campos
      if (fields_data && Array.isArray(fields_data)) {
        for (const field of fields_data) {
          await query('UPDATE document_fields SET value = $1 WHERE id = $2 AND signer_id = $3', [field.value, field.id, s.id]);
        }
      }

      // Efetuar assinatura
      await query(
        `UPDATE document_signers SET status = 'signed', signed_at = NOW(), signed_ip = $1,
         signed_user_agent = $2, signed_geolocation = $3, signature_image_key = $4,
         signature_data = $5, sign_token = NULL WHERE id = $6`,
        [req.ip, req.headers['user-agent'], req.body.geolocation ? JSON.stringify(req.body.geolocation) : null,
         signatureImageKey, signature_data ? JSON.stringify(signature_data) : null, s.id]
      );

      // Criar sessão de assinatura
      await query(
        `INSERT INTO signing_sessions (signer_id, document_id, ip_address, user_agent, geolocation, signed_at)
         VALUES ($1, $2, $3, $4, $5, NOW())`,
        [s.id, s.doc_id, req.ip, req.headers['user-agent'], req.body.geolocation ? JSON.stringify(req.body.geolocation) : null]
      );

      await createAuditLog({ organization_id: s.organization_id, document_id: s.doc_id, signer_id: s.id,
        action: 'signer_signed', description: `${s.name} assinou o documento "${s.doc_name}"`,
        ip_address: req.ip, user_agent: req.headers['user-agent'] as string,
        geolocation: req.body.geolocation, metadata: { auth_method: s.auth_method, signature_type: s.signature_type } });

      // Verificar se todos assinaram (trigger no banco cuida disso, mas confirmamos aqui)
      const pending = await query("SELECT COUNT(*) as c FROM document_signers WHERE document_id = $1 AND status != 'signed'", [s.doc_id]);
      const allSigned = parseInt(pending.rows[0].c) === 0;

      if (allSigned) {
        await createAuditLog({ organization_id: s.organization_id, document_id: s.doc_id,
          action: 'document_completed', description: 'Todas as assinaturas foram coletadas. Documento finalizado.' });
      }

      res.json({ message: 'Documento assinado com sucesso!', all_signed: allSigned });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao assinar documento', details: error.message });
    }
  },

  // POST /api/signing/:token/reject - Recusar assinatura
  async reject(req: Request, res: Response) {
    try {
      const { reason } = req.body;
      const signer = await query(
        `SELECT ds.*, d.organization_id, d.name as doc_name FROM document_signers ds
         JOIN documents d ON d.id = ds.document_id WHERE ds.access_token = $1 AND ds.status IN ('sent', 'opened')`,
        [req.params.token]
      );
      if (signer.rows.length === 0) return res.status(404).json({ error: 'Signatário não encontrado' });

      const s = signer.rows[0];
      await query("UPDATE document_signers SET status = 'rejected', rejected_at = NOW(), rejection_reason = $1 WHERE id = $2", [reason, s.id]);
      await query("UPDATE documents SET status = 'rejected' WHERE id = $1", [s.document_id]);

      await createAuditLog({ organization_id: s.organization_id, document_id: s.document_id, signer_id: s.id,
        action: 'signer_rejected', description: `${s.name} recusou assinar. Motivo: ${reason || 'Não informado'}` });

      res.json({ message: 'Assinatura recusada' });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao recusar', details: error.message });
    }
  },

  // POST /api/signing/:token/upload-photo - Upload de foto do documento
  async uploadDocumentPhoto(req: Request, res: Response) {
    try {
      const { image } = req.body;
      if (!image) return res.status(400).json({ error: 'Imagem é obrigatória' });

      const signer = await query('SELECT ds.*, d.organization_id FROM document_signers ds JOIN documents d ON d.id = ds.document_id WHERE ds.access_token = $1', [req.params.token]);
      if (signer.rows.length === 0) return res.status(404).json({ error: 'Signatário não encontrado' });

      const s = signer.rows[0];
      const imgBuffer = Buffer.from(image.replace(/^data:image\/\w+;base64,/, ''), 'base64');
      const key = `document-photos/${s.document_id}/${s.id}_doc_${Date.now()}.jpg`;
      await uploadFile(key, imgBuffer, 'image/jpeg');

      await query('UPDATE document_signers SET document_photo_key = $1 WHERE id = $2', [key, s.id]);
      res.json({ message: 'Foto do documento enviada', key });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao enviar foto', details: error.message });
    }
  },

  // POST /api/signing/:token/upload-selfie - Upload de selfie com documento
  async uploadSelfie(req: Request, res: Response) {
    try {
      const { image } = req.body;
      if (!image) return res.status(400).json({ error: 'Imagem é obrigatória' });

      const signer = await query('SELECT ds.*, d.organization_id FROM document_signers ds JOIN documents d ON d.id = ds.document_id WHERE ds.access_token = $1', [req.params.token]);
      if (signer.rows.length === 0) return res.status(404).json({ error: 'Signatário não encontrado' });

      const s = signer.rows[0];
      const imgBuffer = Buffer.from(image.replace(/^data:image\/\w+;base64,/, ''), 'base64');
      const key = `selfies/${s.document_id}/${s.id}_selfie_${Date.now()}.jpg`;
      await uploadFile(key, imgBuffer, 'image/jpeg');

      await query('UPDATE document_signers SET selfie_key = $1 WHERE id = $2', [key, s.id]);
      res.json({ message: 'Selfie enviada', key });
    } catch (error: any) {
      res.status(500).json({ error: 'Erro ao enviar selfie', details: error.message });
    }
  },
};
