-- otimizacoes de performance para tabelas operacionais atuais (schema legado em ingles)
-- seguro para execucao multipla e ambientes parcialmente migrados.

DO $$
BEGIN
  IF to_regclass('public.valeris_captures') IS NOT NULL THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_valeris_captures_service_created ON valeris_captures(service_type, created_at DESC)';
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_valeris_captures_created_at ON valeris_captures(created_at DESC)';
  END IF;
END
$$;

DO $$
BEGIN
  IF to_regclass('public.documents') IS NOT NULL THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_documents_company_status_created ON documents(company_id, status, created_at DESC)';
  END IF;
END
$$;

DO $$
BEGIN
  IF to_regclass('public.signers') IS NOT NULL THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_signers_document_order_status ON signers(document_id, sign_order, status)';
  END IF;
END
$$;

DO $$
BEGIN
  IF to_regclass('public.document_fields') IS NOT NULL THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_document_fields_document_page ON document_fields(document_id, page)';
  END IF;
END
$$;

DO $$
BEGIN
  IF to_regclass('public.validation_steps') IS NOT NULL THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_validation_steps_document_signer_order ON validation_steps(document_id, signer_id, "order")';
  END IF;
END
$$;
