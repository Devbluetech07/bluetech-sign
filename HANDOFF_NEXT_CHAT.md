# SignProof - Prompt de Continuidade (Handoff)

Você é um engenheiro sênior continuando o projeto **SignProof** (Flutter Web + Go Fiber + Postgres/pgvector + MinIO + Docker), com foco em funcionamento real ponta a ponta e sem conflitos com outras aplicações locais.

## Contexto e objetivo

- Objetivo principal: fluxo completo de documentos
  1. criar documento
  2. adicionar signatários
  3. definir campos
  4. definir configurações/validações
  5. enviar por e-mail
  6. signatário clicar no link público
  7. assinar campos + completar validações
  8. documento finalizar como `completed`
- Stack:
  - Frontend: Flutter Web
  - Backend: Go + Fiber + GORM
  - Banco: Postgres com pgvector
  - Storage: MinIO
  - Infra: Docker Compose
- A aplicação principal do usuário roda em `3000` e **não pode conflitar**.

## Estado atual implementado

### 1) Isolamento de containers e portas (sem conflito com app principal)

- Compose do SignProof isolado com nomes/portas:
  - `singproof-nginx` -> `4100:80`
  - `singproof-backend` -> `4101:3001`
  - `singproof-postgres` -> `5434:5432`
  - `singproof-minio` -> `29102:29100` e `29103:29101`
- App principal permanece em `3000`.
- Ajustado proxy do Nginx para usar o serviço docker `backend` (e não hostname fixo de container).

### 2) Tela pública de assinatura já existe e está roteada

- Rota pública:
  - `frontend/lib/main.dart` -> `/sign/:token`
  - carrega `PublicSigningPage`
- Tela:
  - `frontend/lib/presentation/signing/public_signing_page.dart`
- Fluxo implementado:
  - carrega dados do token
  - assinatura de campos pendentes
  - validações pós-assinatura (ordem definida)
  - conclusão final

### 3) Integração dos 4 microsserviços Valeris

- Zips extraídos e disponibilizados como UI estática:
  - `backend/static/valeris/assinatura/assinatura.html`
  - `backend/static/valeris/documento/documento.html`
  - `backend/static/valeris/selfie/selfie.html`
  - `backend/static/valeris/selfie_doc/selfie_doc.html`
- Backend serve os arquivos em:
  - `/valeris-ui/*` (definido em `backend/main.go`)
- Nginx faz proxy de:
  - `/valeris-ui/` -> `backend:3001/valeris-ui/`
- Frontend usa iframe web e escuta `postMessage`:
  - `frontend/lib/presentation/microservices/valeris_frame_web.dart`
  - `frontend/lib/presentation/microservices/valeris_frame.dart`
  - `frontend/lib/presentation/microservices/valeris_frame_stub.dart`
- Ao receber sucesso do Valeris:
  - assinatura de campo é concluída
  - validação da etapa é concluída

### 4) Captura Valeris no backend

- Endpoint criado:
  - `POST /api/v1/valeris/captures`
- Arquivos:
  - `backend/controllers/valeris.go`
  - `backend/routes/routes.go`
  - model `ValerisCapture` em `backend/models/extras.go`
  - migrate incluído em `backend/config/database.go`
- Token da captura validado por:
  - env `VALERIS_API_TOKEN`

### 5) E-mail com Resend em todos os fluxos principais

- Serviço central:
  - `backend/controllers/email_service.go`
- Fluxos com Resend:
  - envio documento (`/documents/:id/send`)
  - reenvio (`/documents/:id/resend`)
  - envio integrações (`/integrations/documents/:id/send` via `SendDocument`)
  - token de verificação (`/signing/:token/request-token`)
- Além disso:
  - fluxo sequencial notifica automaticamente próximo signatário quando o anterior conclui.

### 6) Credenciais de teste já disponíveis

- Usuário comum:
  - `usuario@empresa.com`
  - `123456`
- Admin:
  - `admin@valeris.com`
  - `admin123`

## Configuração obrigatória pendente (ambiente real)

Preencher no `docker-compose.yml` (serviço `backend`):

- `RESEND_API_KEY=...`
- `EMAIL_FROM=SignProof <no-reply@seudominio.com>`
- `VALERIS_API_TOKEN=...`

Observação:
- O token usado pelo frontend via `--dart-define=VALERIS_API_TOKEN=...` deve ser o mesmo do backend.

## Como subir para teste

1. Garantir DB `singproof` existente no postgres do compose.
2. Subir:
   - `docker compose up -d --build`
3. Acessos:
   - Frontend: `http://localhost:4100`
   - API base: `http://localhost:4101/api/v1`
   - Health: `http://localhost:4101/health`
   - MinIO console: `http://localhost:29103`

## Próximas tarefas prioritárias

1. Finalizar QA ponta a ponta com Resend real:
   - validar recebimento de e-mails de convite/reenvio/token
2. Melhorar templates de e-mail (HTML) com branding SignProof.
3. Disparar e-mail de documento concluído para remetente e/ou signatários.
4. Refinamento visual pixel a pixel (principalmente documento detalhado e assinatura pública).
5. Hardening:
   - tratamento de erros detalhado em envio de e-mail
   - logs/auditoria mais completos para falhas de notificação

## Prompt pronto para usar em outro chat

Use exatamente este texto no próximo chat:

---
Continue o projeto SignProof do ponto atual sem perder o contexto.

Stack: Flutter Web + Go Fiber + GORM + Postgres (pgvector) + MinIO + Docker.

Regras importantes:
- NÃO gerar conflito com a aplicação principal local (porta 3000).
- Manter SignProof isolado nas portas atuais (4100/4101/5434/29102/29103).
- Continuar com dados reais (sem mock desnecessário).
- Priorizar funcionamento ponta a ponta do fluxo de documentos.

Estado atual:
- Rota pública `/sign/:token` implementada e funcionando.
- Microsserviços Valeris integrados no fluxo de assinatura/validação.
- Endpoint `/api/v1/valeris/captures` criado e persistindo capturas.
- E-mails centralizados via Resend em envio/reenvio/token.
- Fluxo sequencial já notifica próximo signatário.

Arquivos-chave alterados recentemente:
- backend/controllers/email_service.go
- backend/controllers/valeris.go
- backend/controllers/documents.go
- backend/controllers/signing.go
- backend/main.go
- backend/routes/routes.go
- backend/models/extras.go
- backend/config/database.go
- frontend/lib/presentation/signing/public_signing_page.dart
- frontend/lib/presentation/microservices/valeris_frame*.dart
- nginx.conf
- docker-compose.yml

Pendências imediatas:
1) Validar e corrigir fluxo completo com Resend real (convite, reenvio, token, conclusão).
2) Melhorar templates de e-mail e incluir e-mail de conclusão.
3) Refinamento visual pixel a pixel nas telas principais.

Configurar env antes dos testes:
- RESEND_API_KEY
- EMAIL_FROM
- VALERIS_API_TOKEN

Ao finalizar cada etapa, rode validações (go test, flutter analyze/build) e reporte claramente o que foi testado.
---
