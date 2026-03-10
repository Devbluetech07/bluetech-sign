# SignProof Delivery Queue

## Em andamento (Sprint atual)

1. `DONE` Lista de documentos (`/documents`) com filtros, grid/lista, seleção em lote e ações.
2. `DONE` Novo documento 5 passos (`/documents/new`) com signatários, campos visuais, configuração e envio.
3. `DONE` Backend pipeline: signers, fields, validation steps, config, send/cancel/resend.
4. `DONE` Detalhe do documento (`/documents/:id`) com infos, signatários e trilha de auditoria.
5. `DONE` Assinatura pública (`/sign/:token`) com assinatura por campo + etapas de validação.

## Próxima fila (prioridade alta)

6. `NEXT` Contatos (`/contacts`) com:
   - extração automática por signatários
   - criação de contatos fixos
   - preferências padrão por contato (papel, auth, validações)
7. `NEXT` Templates (`/templates`) completo:
   - CRUD
   - upload documento base
   - editor markdown com preview
8. `NEXT` Detalhe visual do editor de campos (Passo 3):
   - drag/resize de campos
   - miniaturas de páginas
   - painel de propriedades

## Fila média

9. `QUEUE` Pastas (`/folders`) com dados reais.
10. `QUEUE` Envio em massa (`/bulk-send`) com CSV real + integração com template.
11. `QUEUE` Equipe (`/team`) com permissões (19 chaves) e persistência.
12. `QUEUE` Departamentos (`/departments`) completo com relação de perfis.
13. `QUEUE` Integrações (`/integrations`) com origem API.
14. `QUEUE` API & Webhooks (`/api-docs`) com CRUD de `api_keys` e `webhooks`.

## Fila admin

15. `QUEUE` Admin dashboard (métricas reais + gráficos).
16. `QUEUE` Admin empresas (campos de plano/limites/status completos).
17. `QUEUE` Admin detalhe empresa (usuários, configs, chaves API).
18. `QUEUE` Admin settings (geral, microsserviços, planos).

## Regras de execução

- Sempre entregar backend + frontend + banco juntos por módulo.
- Evitar mock onde o escopo pede dado real.
- Cada módulo fecha com `flutter analyze`, `go test ./...`, `flutter build web`.
