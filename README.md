# BlueTech Sign

Microservico de assinatura digital da BlueTech Films.

## Tecnologias

| Camada | Tecnologia |
|--------|-----------|
| API | Node.js 20 + Express + TypeScript |
| Frontend | React 18 + Vite + Tailwind CSS |
| Banco | PostgreSQL 16 |
| Cache | Redis 7 |
| Storage | MinIO |
| Infra | Docker + Nginx |

## Desenvolvimento local

```bash
docker compose up -d postgres redis minio
```

```bash
cd apps/api
cp .env.example .env
npm install
npm run dev
```

```bash
cd apps/web
npm install
npm run dev
```

## Credenciais padrao (dev)

| Servico | URL | Login |
|---------|-----|-------|
| App | http://localhost:5173 | admin@bluetechfilms.com.br / Admin@2024 |
| API | http://localhost:3000/api/health | - |
| MinIO | http://localhost:9001 | bluetech_admin / BlueTech@Minio2024 |

## Deploy

Ver `docs/DEPLOY.md`.

## API de Integracao

Ver `docs/API.md`.
