export const DOCUMENT_STATUSES = ['draft', 'pending', 'in_progress', 'completed', 'cancelled', 'expired', 'rejected'] as const;
export const SIGNER_STATUSES = ['pending', 'sent', 'opened', 'signed', 'rejected', 'expired'] as const;
export const SIGNATURE_TYPES = ['assinar', 'testemunha', 'aprovar', 'reconhecer', 'acusar_recebimento'] as const;
export const AUTH_METHODS = ['email_token', 'sms_token', 'whatsapp', 'biometria_facial', 'link', 'presencial'] as const;
