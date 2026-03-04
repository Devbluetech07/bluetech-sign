# Guia de Deploy - BlueTech Sign

## Requisitos
- Ubuntu 22.04 LTS
- Docker 24+ e Docker Compose v2
- 2 vCPU, 4GB RAM, 50GB disco

## Passos

1. Criar `.env.prod` na raiz com segredos de producao.
2. Configurar certificados SSL em `infra/nginx/ssl`.
3. Subir stack:

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

4. Verificar:

```bash
docker compose -f docker-compose.prod.yml ps
curl https://api.bluetechfilms.com.br/api/health
```

## Atualizacao

```bash
git pull origin main
docker compose -f docker-compose.prod.yml up -d --build --no-deps api web
```
