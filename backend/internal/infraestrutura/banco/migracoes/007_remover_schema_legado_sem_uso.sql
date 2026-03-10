-- remove tabelas legadas que nao sao utilizadas pelo backend atual.
-- seguro para execucao multipla em bancos com historico diferente.

DROP TABLE IF EXISTS ai_requests CASCADE;
DROP TABLE IF EXISTS embedding_jobs CASCADE;
DROP TABLE IF EXISTS registros_captura CASCADE;
DROP TABLE IF EXISTS chaves_api CASCADE;
DROP TABLE IF EXISTS perfis CASCADE;

DROP TABLE IF EXISTS chaves_api_organizacao CASCADE;
DROP TABLE IF EXISTS capturas_valeris CASCADE;
DROP TABLE IF EXISTS auditorias CASCADE;
DROP TABLE IF EXISTS etapas_validacao CASCADE;
DROP TABLE IF EXISTS campos_documento CASCADE;
DROP TABLE IF EXISTS assinantes CASCADE;
DROP TABLE IF EXISTS documentos CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;
DROP TABLE IF EXISTS empresas CASCADE;
