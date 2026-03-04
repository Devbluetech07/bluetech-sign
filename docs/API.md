# BlueTech Sign API

Base URL (dev): `http://localhost:3000/api/v1`

Autenticacao:
- `x-api-key: bt_xxxxxxxx`
- `Authorization: Bearer <jwt>`

## Endpoints

- `POST /documents/upload`
- `POST /documents/:id/signers`
- `POST /documents/:id/send`
- `GET /documents/:id`
- `GET /documents/:id/download`
- `GET /contacts`
- `POST /contacts`
- `GET /health`

## Portal publico

- `POST /api/public/request-access`
- `POST /api/public/verify-access`
