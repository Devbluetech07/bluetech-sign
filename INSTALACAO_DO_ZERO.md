# Instalação do Zero — BlueTech Assina

Guia completo para subir o projeto localmente do zero.

---

## Pré-requisitos

- **Docker Desktop** (Windows/Mac) ou **Docker + Docker Compose** (Linux)
- **Git**
- **DBeaver** (para acessar o banco)

> Não precisa instalar Node.js, PostgreSQL, Redis ou MinIO — tudo roda via Docker.

---

## Passo 1 — Clonar o Projeto

```bash
git clone https://github.com/gustavogomes000/assinatura-.git
cd assinatura-
```

Ou se você recebeu o ZIP, extraia e entre na pasta:
```bash
cd bluetech-assina
```

---

## Passo 2 — Subir Tudo com Docker

Um único comando sobe os 5 containers:

```bash
docker compose up -d --build
```

Isso vai:
1. Criar o banco PostgreSQL com todas as 19 tabelas, indexes, triggers e dados de teste
2. Subir o Redis para cache
3. Subir o MinIO para armazenamento de documentos
4. Compilar e subir o Backend (Node.js/TypeScript)
5. Compilar e subir o Frontend (React/Vite)

Primeira vez pode demorar 2-3 minutos para baixar as imagens.

---

## Passo 3 — Verificar se Tudo Subiu

```bash
docker compose ps
```

Todos os 5 serviços devem estar "Up":
- `bluetech-postgres`
- `bluetech-redis`
- `bluetech-minio`
- `bluetech-backend`
- `bluetech-frontend`

---

## Passo 4 — Acessar o Sistema

| O que            | URL                          |
|------------------|------------------------------|
| **Frontend**     | http://localhost:5173         |
| **Backend API**  | http://localhost:3000         |
| **MinIO Console**| http://localhost:9001         |

### Login:
- **Admin:** admin@bluetechfilms.com.br / Admin@2024
- **Operador:** operador@bluetechfilms.com.br / Admin@2024

---

## Passo 5 — Conectar DBeaver ao Banco

1. Abra o DBeaver
2. Nova Conexão → PostgreSQL
3. Preencha:
   - **Host:** localhost
   - **Port:** 5432
   - **Database:** bluetech_assina
   - **Username:** bluetech
   - **Password:** BlueTech@2024
4. Teste a conexão → OK
5. Explore as 19 tabelas em `public`

---

## Passo 6 — Testar o Fluxo Completo

### 6.1 Criar e enviar um documento:
1. Faça login como admin
2. Clique em "Novo Documento"
3. Faça upload de um PDF
4. Adicione signatários (pode usar emails fictícios para teste)
5. Escolha método de autenticação (Token Email, Biometria, etc.)
6. Clique em "Enviar"

### 6.2 Simular assinatura:
1. No banco (DBeaver), consulte a tabela `document_signers`
2. Copie o `access_token` do signatário
3. Acesse: `http://localhost:5173/sign/{access_token}`
4. Siga o fluxo: visualizar → verificar identidade → assinar

### 6.3 Verificar no banco:
- `documents` — status muda para `completed` quando todos assinam
- `audit_logs` — todo o histórico registrado
- `signing_sessions` — dados da sessão de assinatura

---

## Configurações Opcionais

### Habilitar Biometria Facial
Edite o `docker-compose.yml`, na seção `backend.environment`:
```yaml
BLUEPOINT_API_KEY: "sua-chave-aqui"
```
Depois: `docker compose up -d backend`

### Habilitar envio de Email real
```yaml
SMTP_USER: "seuemail@gmail.com"
SMTP_PASS: "senha-de-app-google"
```
> Para Gmail, use "Senhas de App" (não a senha normal).

### Apontar MinIO para produção
```yaml
MINIO_ENDPOINT: midias.bluetechfilms.com.br
MINIO_PORT: 443
MINIO_USE_SSL: "true"
```

---

## Comandos Úteis

```bash
# Ver logs de todos os serviços
docker compose logs -f

# Ver logs só do backend
docker compose logs -f backend

# Reiniciar tudo
docker compose restart

# Parar tudo
docker compose down

# Parar e apagar dados (reset total)
docker compose down -v

# Rebuild após mudanças no código
docker compose up -d --build
```

---

## Estrutura de Pastas

```
bluetech-assina/
├── docker-compose.yml          # Orquestração dos 5 containers
├── docker/
│   └── init.sql                # Schema completo (19 tabelas + seeds)
├── backend/
│   ├── Dockerfile
│   ├── package.json
│   ├── tsconfig.json
│   ├── .env / .env.example
│   └── src/
│       ├── server.ts           # Entry point
│       ├── config/
│       │   ├── database.ts     # Pool PostgreSQL
│       │   ├── redis.ts        # Cache Redis
│       │   └── minio.ts        # Storage MinIO
│       ├── middleware/
│       │   ├── auth.ts         # JWT + API Key + roles
│       │   └── upload.ts       # Multer (upload de arquivos)
│       ├── controllers/
│       │   ├── authController.ts       # Login, registro, perfil
│       │   ├── documentsController.ts  # CRUD documentos + workflow
│       │   ├── signingController.ts    # Assinatura pública
│       │   └── crudControllers.ts      # Templates, pastas, contatos, users, webhooks, settings, tags, reports
│       ├── services/
│       │   ├── auditService.ts         # Log de auditoria
│       │   ├── biometriaService.ts     # Integração BluePoint API
│       │   └── emailService.ts         # Envio de emails + templates HTML
│       └── routes/
│           └── index.ts                # Todas as rotas da API
├── frontend/
│   ├── Dockerfile
│   ├── package.json
│   ├── vite.config.ts
│   ├── tailwind.config.js
│   ├── index.html
│   ├── public/
│   │   └── favicon.svg
│   └── src/
│       ├── main.tsx
│       ├── App.tsx             # Layout + Routing + Sidebar
│       ├── index.css           # Tailwind + custom styles
│       ├── store/
│       │   └── authStore.ts    # Zustand (estado global)
│       ├── services/
│       │   └── api.ts          # Axios (todas as chamadas API)
│       └── pages/
│           ├── LoginPage.tsx
│           ├── DashboardPage.tsx
│           ├── DocumentsPage.tsx
│           ├── DocumentDetailPage.tsx
│           ├── NewDocumentPage.tsx
│           ├── SigningPage.tsx          # Página pública de assinatura
│           ├── TemplatesPage.tsx
│           ├── FoldersPage.tsx
│           ├── ContactsPage.tsx
│           ├── UsersPage.tsx
│           ├── SettingsPage.tsx
│           └── ReportsPage.tsx
├── README.md
├── INSTALACAO_DO_ZERO.md
└── .gitignore
```

---

## Endpoints da API

### Auth
- `POST /api/auth/login` — Login
- `POST /api/auth/register` — Registro
- `GET /api/auth/me` — Dados do usuário logado
- `PUT /api/auth/profile` — Atualizar perfil
- `PUT /api/auth/password` — Alterar senha

### Documentos
- `GET /api/documents` — Listar (com filtros, paginação)
- `GET /api/documents/:id` — Detalhes + signatários + campos + audit
- `POST /api/documents/upload` — Upload
- `PUT /api/documents/:id` — Atualizar
- `DELETE /api/documents/:id` — Excluir
- `POST /api/documents/:id/signers` — Adicionar signatário
- `DELETE /api/documents/:id/signers/:sid` — Remover signatário
- `POST /api/documents/:id/fields` — Adicionar campo
- `POST /api/documents/:id/send` — Enviar para assinatura
- `POST /api/documents/:id/cancel` — Cancelar
- `POST /api/documents/:id/reminder` — Reenviar lembrete
- `GET /api/documents/:id/download` — Download
- `GET /api/documents/stats` — Dashboard stats

### Assinatura Pública (sem auth)
- `GET /api/signing/:token` — Carregar documento
- `POST /api/signing/:token/request-token` — Solicitar código
- `POST /api/signing/:token/verify-token` — Verificar código
- `POST /api/signing/:token/verify-biometria` — Verificar face
- `POST /api/signing/:token/sign` — Assinar
- `POST /api/signing/:token/reject` — Recusar
- `POST /api/signing/:token/upload-photo` — Foto de documento
- `POST /api/signing/:token/upload-selfie` — Selfie

### Templates, Pastas, Contatos, Usuários, Tags, Webhooks, Settings, Relatórios
(Ver README.md para lista completa)

---

## Pronto!

Depois de `docker compose up -d --build`, acesse http://localhost:5173 e use o sistema.
