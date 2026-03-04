export type DocumentStatus = 'draft' | 'pending' | 'in_progress' | 'completed' | 'cancelled' | 'expired' | 'rejected';
export type SignerStatus = 'pending' | 'sent' | 'opened' | 'signed' | 'rejected' | 'expired';
export type SignatureType = 'assinar' | 'testemunha' | 'aprovar' | 'reconhecer' | 'acusar_recebimento';
export type AuthMethod = 'email_token' | 'sms_token' | 'whatsapp' | 'biometria_facial' | 'link' | 'presencial';
export type DocumentType = 'rg' | 'cnh' | 'passaporte' | 'rne' | 'certidao' | 'outro';
export type UserRole = 'admin' | 'manager' | 'operator' | 'viewer';

export interface Permissions {
  documents: boolean;
  templates: boolean;
  contacts: boolean;
  reports: boolean;
  settings: boolean;
  api_keys: boolean;
}

export interface Organization {
  id: string;
  name: string;
  email?: string;
  phone?: string;
  cnpj?: string;
  logo_url?: string;
}

export interface User {
  id: string;
  organization_id: string;
  name: string;
  email: string;
  role: UserRole;
  permissions: Partial<Permissions>;
}

export interface Document {
  id: string;
  name: string;
  status: DocumentStatus;
  organization_id: string;
  created_at: string;
  updated_at: string;
}

export interface SignerMetadata {
  require_face_photo?: boolean;
  require_document_photo?: boolean;
  require_selfie?: boolean;
  require_handwritten?: boolean;
  require_residence_proof?: boolean;
}

export interface Signer {
  id: string;
  document_id: string;
  name: string;
  email: string;
  status: SignerStatus;
  signature_type: SignatureType;
  auth_method: AuthMethod;
  metadata?: SignerMetadata;
}

export interface DocumentField {
  id: string;
  document_id: string;
  signer_id: string;
  field_type: string;
  page: number;
  x: number;
  y: number;
  width: number;
  height: number;
  required: boolean;
}

export interface AuditLog {
  id: string;
  action: string;
  description?: string;
  created_at: string;
}

export interface Folder {
  id: string;
  name: string;
  color?: string;
}

export interface Contact {
  id: string;
  name: string;
  email: string;
  cpf?: string;
  phone?: string;
}

export interface Template {
  id: string;
  name: string;
  status: string;
}

export interface Tag {
  id: string;
  name: string;
  color?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  page: number;
  limit: number;
  total: number;
}

export interface ApiError {
  error: string;
  details?: unknown;
}
