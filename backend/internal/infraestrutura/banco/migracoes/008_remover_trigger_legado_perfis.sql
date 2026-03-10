-- remove trigger legado que tentava inserir em tabela "perfis" (schema antigo).

DROP TRIGGER IF EXISTS on_new_user ON users;
DROP FUNCTION IF EXISTS handle_new_user();
