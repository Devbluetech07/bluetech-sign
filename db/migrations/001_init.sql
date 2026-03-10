CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  nome_completo TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS perfis (
  id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  nome_completo TEXT,
  empresa TEXT,
  url_avatar TEXT,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chaves_api (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  prefixo_chave TEXT NOT NULL,
  hash_chave TEXT NOT NULL UNIQUE,
  perfil_escopo TEXT NOT NULL DEFAULT 'completo',
  ativo BOOLEAN NOT NULL DEFAULT TRUE,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ultimo_uso TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_chaves_usuario ON chaves_api(usuario_id);
CREATE INDEX IF NOT EXISTS idx_chaves_hash ON chaves_api(hash_chave);

CREATE TABLE IF NOT EXISTS registros_captura (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id UUID REFERENCES users(id) ON DELETE SET NULL,
  tipo_servico TEXT NOT NULL CHECK (tipo_servico IN ('assinatura','documento','selfie','selfie-documento')),
  status TEXT NOT NULL DEFAULT 'concluido',
  caminho_arquivo TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  endereco TEXT,
  resultado_validacao JSONB NOT NULL DEFAULT '{}'::JSONB,
  metadados JSONB NOT NULL DEFAULT '{}'::JSONB,
  image_data TEXT,
  embedding vector(1536),
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_registros_usuario ON registros_captura(usuario_id);
CREATE INDEX IF NOT EXISTS idx_registros_tipo ON registros_captura(tipo_servico);
CREATE INDEX IF NOT EXISTS idx_registros_criado ON registros_captura(criado_em DESC);
CREATE INDEX IF NOT EXISTS idx_registros_metadados ON registros_captura USING gin(metadados);
CREATE INDEX IF NOT EXISTS idx_registros_embedding ON registros_captura USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);

CREATE OR REPLACE FUNCTION handle_new_user() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO perfis (id, nome_completo) VALUES (NEW.id, COALESCE(NEW.nome_completo,'')) ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_new_user ON users;
CREATE TRIGGER on_new_user AFTER INSERT ON users FOR EACH ROW EXECUTE FUNCTION handle_new_user();

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS users_updated_at ON users;
CREATE TRIGGER users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
