# Modelo Relacional Canonico (PT-BR)

Este projeto passa a ter um modelo de banco canonico em portugues, preparado para multi-tenant interno.

## Principios

- `empresa_id` como chave de tenant em entidades de negocio.
- nomes de tabela e coluna em portugues no modelo canonico.
- indices compostos por tenant + status + data para consultas frequentes.
- constraints e `ON DELETE` explicitos para integridade.

## Mapeamento de dominio

| Dominio | Tabela canonica |
|---|---|
| Empresas | `empresas` |
| Usuarios | `usuarios` |
| Documentos | `documentos` |
| Assinantes | `assinantes` |
| Campos de assinatura | `campos_documento` |
| Etapas de validacao | `etapas_validacao` |
| Auditoria | `auditorias` |
| Capturas de biometria/documento | `capturas_valeris` |
| Chaves de integracao | `chaves_api_organizacao` |

## Observacao de compatibilidade

O backend atual continua operando com os modelos existentes para evitar regressao funcional imediata.
O modelo canonico em portugues ja esta versionado em migracao SQL para evolucao incremental sem quebra.
