# Setup Local

## 1) Infraestrutura

```bash
docker compose up -d postgres redis minio
```

## 2) API

```bash
cd apps/api
cp .env.example .env
npm install
npm run dev
```

## 3) Web

```bash
cd apps/web
npm install
npm run dev
```
