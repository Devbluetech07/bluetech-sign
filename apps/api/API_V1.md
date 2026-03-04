# BlueTech Assina API v1

Base URL:

- `http://localhost:3000/api/v1` (dev)

Autenticacao (uma das opcoes):

- `x-api-key: bt_xxxxxxxxxx`
- `Authorization: Bearer <jwt_token>`

## Documents

- `POST /documents/upload` - Upload de PDF/DOCX e cria documento.
- `POST /documents/:id/signers` - Adiciona signatario.
- `POST /documents/:id/send` - Envia documento para assinatura.
- `GET /documents/:id` - Consulta detalhes e status.
- `GET /documents/:id/download` - Gera link temporario para download.

## Contacts

- `GET /contacts` - Lista contatos da organizacao.
- `POST /contacts` - Cria novo contato.

## Webhooks

Configuracao via painel (Settings > Integracoes).

Payload padrao:

```json
{
  "event": "document.completed",
  "document_id": "uuid",
  "document_name": "Contrato XYZ",
  "signers": []
}
```

## Public access (portal do signatario)

- `POST /api/public/request-access` - envia codigo de acesso para email.
- `POST /api/public/verify-access` - valida codigo e retorna documentos vinculados.
