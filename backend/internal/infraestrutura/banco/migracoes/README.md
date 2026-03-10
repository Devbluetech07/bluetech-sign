# Governanca de Migracoes SQL

Este diretorio e a fonte oficial de evolucao de schema do banco.

## Regras

1. Toda mudanca de banco entra como novo arquivo SQL versionado.
2. Nao editar arquivos de migracao antigos ja executados em ambientes compartilhados.
3. Nomear no formato `NNN_descricao.sql` (ex.: `005_ajustar_indices_documentos.sql`).
4. Scripts devem ser idempotentes (`IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`, etc.).
5. Otimizacoes de performance devem priorizar o schema operacional atual e manter compatibilidade com migracoes anteriores.

## Ordem atual (enxuta)

- `001_schema_operacional_essencial.sql`: schema unico oficial usado pelo backend atual.
- `004_otimizacoes_operacionais.sql`: indices e tuning para tabelas operacionais em uso.
- `005_perfis_integracao_bluepoint.sql`: campos de integracao externa em `profiles`.
- `006_colaboradores_externos_bluepoint.sql`: cache local de colaboradores externos por empresa.
- `007_remover_schema_legado_sem_uso.sql`: limpeza de tabelas legadas que nao sao usadas.

## Execucao

O backend executa automaticamente as migracoes pendentes no startup por meio de `controle_migracoes`.
O mesmo arquivo nunca e reaplicado no mesmo banco.
