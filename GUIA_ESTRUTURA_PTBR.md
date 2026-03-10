# Guia de Estrutura (PT-BR)

Este guia descreve, em linguagem simples, o que cada pasta/arquivo principal faz.

## Pastas principais

- `backend-go`: API principal em Go (autenticação, captura, embeddings, integração com banco e MinIO).
- `frontend-web`: telas web (portal, componentes de captura e documentação).
- `db`: scripts SQL de estrutura e evolução do banco.
- `scripts`: utilitários operacionais (backup, restore, saúde).
- `backups`: saídas dos backups SQL gerados localmente.

## Arquivos principais

- `.env`: variáveis de ambiente do projeto.
- `docker-compose.yml`: sobe backend, frontend, PostgreSQL, MinIO e serviços auxiliares.
- `README_PRODUCAO.md`: guia de deploy/integração para produção.
- `links_teste.md`: links locais para validação rápida dos fluxos.

## Scripts operacionais

- `scripts/backup_banco.ps1`: gera backup SQL do PostgreSQL.
- `scripts/restaurar_banco.ps1`: restaura um backup SQL no PostgreSQL.
- `scripts/verificar_saude.ps1`: valida saúde da API e fila de embeddings.

## Observação sobre nomes técnicos

As pastas de código (`backend-go`, `frontend-web`, `db`) foram mantidas para preservar compatibilidade com imports, Docker e automações existentes.
Os arquivos operacionais e guias foram normalizados em português para facilitar manutenção do time.
