# Setup dos Microsservicos Valeris

Os componentes foram integrados no projeto em:

- `backend/static/valeris/assinatura/assinatura.html`
- `backend/static/valeris/documento/documento.html`
- `backend/static/valeris/selfie/selfie.html`
- `backend/static/valeris/selfie_doc/selfie_doc.html`

## Onde preencher o token

### Backend (obrigatorio)
Defina a variavel de ambiente:

- `VALERIS_API_TOKEN`

Exemplo em `docker-compose.yml`:

```yaml
- VALERIS_API_TOKEN=vl_312035606bc79810dce7fc61715b142b6b57a42f66702224d7b080a40232f788
```

### Frontend (recomendado)
Passe o mesmo token via build do Flutter:

```powershell
flutter run -d chrome --dart-define=VALERIS_API_TOKEN=vl_312035606bc79810dce7fc61715b142b6b57a42f66702224d7b080a40232f788
```

Ou para build:

```powershell
flutter build web --dart-define=VALERIS_API_TOKEN=vl_312035606bc79810dce7fc61715b142b6b57a42f66702224d7b080a40232f788
```

> O token do frontend precisa ser igual ao `VALERIS_API_TOKEN` do backend.

## API usada pelos componentes

Os microsservicos chamam automaticamente:

- `POST /api/v1/valeris/captures`

com header:

- `Authorization: Bearer <VALERIS_API_TOKEN>`

## Fluxo integrado

- Assinatura de campo: abre `assinatura.html` em iframe e conclui o campo ao receber `VALERIS_CAPTURE_SUCCESS`.
- Validacoes: abre automaticamente o microservico correto conforme etapa:
  - `selfie` -> `selfie.html`
  - `document` -> `documento.html`
  - `selfie + document` -> `selfie_doc.html`

## URL de acesso dos componentes

Quando a stack estiver de pé com Nginx:

- `http://localhost:4100/valeris-ui/assinatura/assinatura.html`
- `http://localhost:4100/valeris-ui/selfie/selfie.html`

## Envio de e-mails com Resend (obrigatório para fluxo completo)

No `docker-compose.yml`, serviço `backend`, preencha:

- `RESEND_API_KEY=COLE_SUA_CHAVE_RESEND_AQUI`
- `EMAIL_FROM=SignProof <no-reply@seudominio.com>`

Fluxos que agora usam Resend:

- envio inicial de documento (`/documents/:id/send`)
- reenvio de documento (`/documents/:id/resend`)
- envio por integrações (`/integrations/documents/:id/send`)
- token de verificação por e-mail (`/signing/:token/request-token`)
