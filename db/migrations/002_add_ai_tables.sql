-- add queue and telemetry tables for AI features

ALTER TABLE registros_captura
  ADD COLUMN IF NOT EXISTS embedding_jobs_id SERIAL; -- we will track job separately, not required though

CREATE TABLE IF NOT EXISTS embedding_jobs (
  id SERIAL PRIMARY KEY,
  captura_id UUID REFERENCES registros_captura(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('pending','processing','done','failed')) DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_embedding_jobs_status ON embedding_jobs(status);

CREATE TABLE IF NOT EXISTS ai_requests (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  prompt TEXT,
  response TEXT,
  tokens_used INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_requests_user ON ai_requests(user_id);
