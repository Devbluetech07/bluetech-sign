# Prompt de Continuação: SignProof - Identidade Gamificada e Fluxo Avançado

**Contexto do Projeto:**
Estamos desenvolvendo o **SignProof**, um SaaS de assinaturas digitais com backend em **Go (Fiber + GORM)** e frontend em **Flutter (Web)**. A infraestrutura roda em **Docker** (Postgres, MinIO, Nginx).

**Identidade Visual (Gamified Glassmorphism):**
O sistema segue uma estética futurista inspirada em RPGs e Glassmorphism:
- **Cores:** Teal (Azul Petróleo) Profundo para Âmbar/Dourado Soft. Acentos em Neon Teal e Neon Gold.
- **Efeitos:** Cartões translúcidos (`GlassContainer`) com desfoque de fundo (backdrop filter), bordas finas e brilhantes.
- **Terminologia RPG:** Documentos = "Missões", Upload = "Matriz", Signatários = "Alvos", etc.

**O que já foi feito:**
1.  **Infra:** Docker configurado (Backend 3001, Frontend 4000). Resolvidos bugs de CORS e Proxy.
2.  **UI Core:** `AppTheme.dart` centralizando cores/fontes e `GlassContainer.dart` para o efeito de vidro.
3.  **Telas Refatoradas:**
    -   `LoginPage.dart`: Portal cyber-tech com abas de Usuário/Sistema.
    -   `DashboardPage.dart`: Cards de Nível, barras de XP e ações recomendadas.
    -   `DocumentsPage.dart`: Listagem ("Missões") em grid/lista com badges HUD.
    -   `AdminCompaniesPage.dart`: Gestão de empresas (instâncias) com tema Dourado.
    -   `AdminCompanyDetailsPage.dart`: Detalhes da empresa com gestão de usuários e reset de senha.

**O que estava sendo feito AGORA (Seu ponto de partida):**
Estamos implementando o **Fluxo de Documentos Avançado** baseado na imagem da "Lovable" (5 passos: Documento, Signatários, Campos, Configurar, Enviar).

**Próximos Passos Imediatos:**
1.  **Refatorar `document_flow_page.dart`**:
    -   Implementar o wizard de 5 passos com cabeçalho de progresso tecnológico.
    -   **Passo 2 (Signatários):** Adicionar múltiplos signatários com dropdown de papéis (Signatário, Testemunha, Aprovador, etc.).
    -   **Validações Pós-Assinatura:** Implementar a lógica de seleção (Selfie, Foto Documento) e o painel de reordenação ("Ordem do Fluxo") com setas ou arrastar.
2.  **Backend (`admin.go` e `documents.go`)**:
    -   Atualizar o modelo `Signer` para suportar a lista de `RequiredValidations` (ex: "selfie,doc_photo").
    -   Ajustar os controllers para receber e processar essas validações no envio do documento.
3.  **Build Final**:
    -   Ao terminar os ajustes de UI, rodar `flutter build web` e testar no navegador (`localhost:4000`).

**Credenciais de Teste:**
-   **SuperAdmin:** `admin@valeris.com` / `admin123` (Caminho `/admin/companies`).
-   **Empresa:** Criar via Admin ou usar uma existente `usuario@empresa.com`.

**Arquivos Importantes:**
-   `frontend/lib/core/app_theme.dart`
-   `frontend/lib/presentation/widgets/glass_container.dart`
-   `frontend/lib/presentation/document_flow/document_flow_page.dart`
-   `backend/controllers/admin.go`
-   `backend/models/document.go`

**Objetivo Central:** Manter a "cara" de jogo futurista premium em todas as interações.
