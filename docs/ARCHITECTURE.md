# Arquitetura

BlueTech Sign segue arquitetura em duas aplicacoes:

- `apps/api`: API Node.js/Express com PostgreSQL, Redis e MinIO.
- `apps/web`: SPA React/Vite para operacao interna e portal publico.

Camadas principais:
- Controllers: orquestracao HTTP.
- Services: regras de negocio e integracoes (email, biometria, webhooks).
- Config: conexoes e environment.
- Routes: separacao entre rotas internas, publicas e API v1.
