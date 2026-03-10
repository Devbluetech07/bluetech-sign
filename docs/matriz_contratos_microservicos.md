# Matriz de Contratos dos Microservicos Legados (Node/TS)

Este documento registra o contrato atual dos microservicos legados para garantir migracao 1:1 para Go.

## Contrato comum

- Endpoint: `POST /processar`
- Content-Type: `application/json`
- Body:
  - `image_data` (string, obrigatorio)
  - `metadata` (objeto, opcional)
- Erro de validacao:
  - HTTP `400`
  - Body: `{ "erro": "image_data e obrigatorio" }`
- Sucesso:
  - HTTP `200`
  - Body: `{ "status": "ok", "service_type": "<tipo>" }`

## Diferencas por servico

| Servico legado | service_type enviado ao backend principal |
|---|---|
| `ms-documento` | `documento` |
| `ms-selfie` | `selfie` |
| `ms-selfie-documento` | `selfie-documento` |

## Integracao com backend principal

- URL destino: `MAIN_BACKEND_URL` (default: `http://localhost:4101/api/v1/valeris/captures`)
- Header de autenticacao:
  - `Authorization: Bearer <VALERIS_API_TOKEN>`
- Payload encaminhado:
  - `service_type`
  - `image_data`
  - `metadata`

## Requisitos de compatibilidade da migracao Go

1. Preservar rota, metodo, campos e codigos HTTP.
2. Preservar semantica do `service_type` por microservico.
3. Preservar encaminhamento para backend principal com token bearer.
4. Retornar mensagens em portugues.
