-- campos adicionais para mapear dados externos de colaborador/cargo/departamento
-- sem quebrar ambientes que ainda nao tenham a tabela profiles.

DO $$
BEGIN
  IF to_regclass('public.profiles') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE profiles ADD COLUMN IF NOT EXISTS external_collaborator_id BIGINT';
    EXECUTE 'ALTER TABLE profiles ADD COLUMN IF NOT EXISTS external_department_id BIGINT';
    EXECUTE 'ALTER TABLE profiles ADD COLUMN IF NOT EXISTS external_department_name TEXT';
    EXECUTE 'ALTER TABLE profiles ADD COLUMN IF NOT EXISTS external_cargo_id BIGINT';
    EXECUTE 'ALTER TABLE profiles ADD COLUMN IF NOT EXISTS external_cargo_name TEXT';
  END IF;
END
$$;
