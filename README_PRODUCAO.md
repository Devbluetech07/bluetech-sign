# Valeris v2.0 - Guia de Produção e Integração

Este projeto é uma solução completa de KYC (Know Your Customer) e Assinatura Digital, preparada para ser escalável e segura.

## 📁 Estrutura do Projeto

- **`/backend-go`**: Servidor em Go (Gin) que gerencia autenticação, banco de dados (PostgreSQL + pgvector) e armazenamento de imagens (MinIO).
- **`/frontend-web`**: Portal administrativo, documentação interativa e os componentes dos microsserviços.
- **`/db/migrations`**: Scripts SQL para inicializar o banco de dados com suporte a vetores.
- **`docker-compose.yml`**: Orquestração para subir o banco, o MinIO e a API.

> Para facilitar leitura do time, também existe o guia em português com descrição das pastas e arquivos: `GUIA_ESTRUTURA_PTBR.md`.

---

## 🚀 Como subir para o Servidor

1.  **Configurar Variáveis**: Duplique o `.env` e configure as credenciais de produção para o PostgreSQL e MinIO.
    - Use `FRONTEND_URLS` com os domínios permitidos no CORS (separados por vírgula).
    - Use `MINIO_PUBLIC_BUCKET=false` em produção para bucket privado.
2.  **Docker**: Execute `docker-compose up -d` na raiz do projeto. Isso criará todos os containers necessários.
3.  **DNS/Proxy**: Aponte seu domínio para a porta `3001` (API) e `3000` (Frontend). Recomenda-se o uso de Nginx com HTTPS (obrigatório para uso de câmera em navegadores).

---

## 🤝 Como Integrar (Explicação para Iniciantes)

Imagine que o Valeris é um "pequeno aplicativo de câmera" que você pode colocar dentro do seu site ou aplicativo.

### 1. Fluxo de Dados (Simples)
1.  Sua aplicação gera um **Token** chamando `/api/auth/login`.
2.  Você abre um **iFrame** ou **WebView** apontando para o Valeris com esse token.
3.  O usuário tira a foto. O SDK do Valeris valida se a foto está boa (luz, foco, cor).
4.  O Valeris salva a imagem direto no **MinIO** e os dados no **Banco**.
5.  O Valeris avisa seu sistema que a captura acabou.

### 2. Integração Flutter (App Mobile)
Use o componente `WebView`. Quando o usuário terminar a captura, o Valeris enviará uma mensagem via JavaScript que o Flutter captura:
```dart
// Flutter escutando o sucesso
onMessageReceived: (message) {
  if (message.message.contains('VALERIS_CAPTURE_SUCCESS')) {
     // Aqui você sabe que o usuário terminou!
  }
}
```

### 3. Integração Go (Servidor)
Seu servidor Go pode consultar as capturas do usuário a qualquer momento:
```go
// Consultar captura por ID
resp, _ := http.Get("http://api.valeris/api/captures/" + id)
```

---

## 🛡️ Segurança e Alta Precisão
- **Anti-Fraude**: O algoritmo verifica a saturação da cor. Fotos em preto e branco de telas são rejeitadas.
- **Trava de Documento**: O sistema exige que o documento esteja bem enquadrado por 2 segundos antes de permitir a captura, garantindo nitidez.
- **Metadados**: Capturamos IP, Localização (GPS), Dispositivo e Fuso Horário automaticamente para auditoria.

## 🔁 Backup e Saúde

- Backup PostgreSQL: `powershell -ExecutionPolicy Bypass -File .\scripts\backup_banco.ps1`
- Restore PostgreSQL: `powershell -ExecutionPolicy Bypass -File .\scripts\restaurar_banco.ps1 -ArquivoBackup .\backups\SEU_ARQUIVO.sql`
- Health check API + embeddings: `powershell -ExecutionPolicy Bypass -File .\scripts\verificar_saude.ps1`

**Dúvidas?** Consulte a aba [Documentação](http://localhost:3000/components/docs.html) no portal.
