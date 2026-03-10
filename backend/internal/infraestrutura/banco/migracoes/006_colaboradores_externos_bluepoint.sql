-- cache local de colaboradores da BluePoint para buscas rapidas e historico operacional.

CREATE TABLE IF NOT EXISTS company_external_collaborators (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  external_collaborator_id BIGINT NOT NULL,
  external_department_id BIGINT,
  external_department_name TEXT,
  full_name TEXT NOT NULL,
  email TEXT,
  status TEXT,
  photo_url TEXT,
  cargo_id BIGINT,
  cargo_name TEXT,
  raw_payload TEXT,
  synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uidx_company_external_collaborator UNIQUE (company_id, external_collaborator_id)
);

CREATE INDEX IF NOT EXISTS idx_company_external_collaborators_company
  ON company_external_collaborators(company_id);

CREATE INDEX IF NOT EXISTS idx_company_external_collaborators_email
  ON company_external_collaborators(email);

CREATE INDEX IF NOT EXISTS idx_company_external_collaborators_department
  ON company_external_collaborators(company_id, external_department_id);
