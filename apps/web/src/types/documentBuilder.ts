export type FieldType =
  | 'text'
  | 'signature'
  | 'initial'
  | 'date'
  | 'number'
  | 'image'
  | 'checkbox'
  | 'multiple'
  | 'file'
  | 'radio'
  | 'select'
  | 'cells'
  | 'stamp';

export interface DocumentField {
  id: string;
  document_id: string;
  signer_id: string;
  field_type: FieldType;
  label?: string;
  required: boolean;
  page: number;
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface SignerMetadata {
  require_face_photo: boolean;
  require_document_photo: boolean;
  document_photo_type: string;
  document_photo_sides: 'front' | 'both';
  require_selfie: boolean;
  require_handwritten: boolean;
  require_residence_proof: boolean;
}

export interface SignerConfig {
  id?: string;
  temp_id: string;
  name: string;
  email: string;
  cpf?: string;
  phone?: string;
  signature_type: string;
  auth_method: string;
  sign_order: number;
  metadata: SignerMetadata;
}
