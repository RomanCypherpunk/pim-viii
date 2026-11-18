# Alunos Tech Hub

> Plataforma corporativa para gestão ágil de projetos e chamados, com API REST, painel web, aplicativo móvel e módulo desktop.

Projeto desenvolvido para o **PIM VIII** do Curso Superior de Tecnologia em Análise e Desenvolvimento de Sistemas (UNIP EaD).
Aluno: Enzo Xavier Santos (RA 2620639). Orientador: Prof. Me. José Lorandi.

O documento acadêmico está em [`docs/trabalho-final/`](docs/trabalho-final/). Os registros de execução (saídas de comandos, capturas de tela) estão em [`docs/evidencias/`](docs/evidencias/).

---

## Stack

| Camada | Tecnologia |
| --- | --- |
| API | ASP.NET Core Web API (.NET 10), JWT, perfis, rate limit, health checks, `/metrics` (Prometheus) |
| Camadas | `Domain` → `Application` → `Infrastructure` → `Api` |
| Banco | SQL Server 2022 · funções, procedures, triggers, transações, Row-Level Security, mascaramento, `ROWVERSION` |
| Acesso a dados | Dapper (procedures e consultas) · migrações por scripts SQL com DbUp |
| Web | ASP.NET Core MVC (consome a API) |
| Desktop | WPF com MVVM (.NET 10) |
| Mobile | Flutter (Dart) |
| DevOps | Docker (multi-stage, usuário não-root) · Docker Compose · Kubernetes (kind) · GitHub Actions |
| Testes | xUnit + FluentAssertions · Flutter test |

## Estrutura

```text
alunostech-hub/
├── src/
│   ├── AlunosTech.Domain/          # entidades, regras, eventos, estratégias de SLA
│   ├── AlunosTech.Application/     # casos de uso, interfaces, notificações
│   ├── AlunosTech.Infrastructure/  # Dapper, DbUp, cache (Decorator)
│   ├── AlunosTech.Api/             # controllers, JWT, health, métricas
│   ├── AlunosTech.Web/             # painel MVC
│   └── AlunosTech.Desktop/         # módulo WPF (MVVM)
├── mobile/alunostech_mobile/       # aplicativo Flutter
├── tests/AlunosTech.Domain.Tests/  # 27 testes
├── database/                       # migrations, functions, procedures, triggers, security, seed, performance
├── infra/                          # docker/, k8s/, scripts/
├── .github/workflows/              # ci.yml e cd.yml
└── docs/                           # evidências e trabalho final
```

## Como executar

Pré-requisitos: .NET SDK 10, Docker Desktop. Para o cluster: `kind` e `kubectl`. Para o app móvel: Flutter.

```powershell
# 1. configuração (nunca versione o .env)
copy .env.example .env      # ajuste MSSQL_SA_PASSWORD e JWT_KEY

# 2. banco
docker compose up -d sqlserver

# 3. API (aplica os scripts SQL no primeiro start e cria os usuários de desenvolvimento)
$env:ASPNETCORE_ENVIRONMENT='Development'; $env:ASPNETCORE_URLS='http://localhost:5080'
dotnet run --project src/AlunosTech.Api --no-launch-profile

# 4. painel web (outro terminal)
$env:Api__BaseUrl='http://localhost:5080'; $env:ASPNETCORE_URLS='http://localhost:5200'
dotnet run --project src/AlunosTech.Web --no-launch-profile

# 5. desktop (Windows)
dotnet run --project src/AlunosTech.Desktop

# 6. mobile
cd mobile/alunostech_mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:5080     # emulador Android
```

Usuários de desenvolvimento (senha padrão `AlunosTech@2026`, definida em `Seed:SenhaPadrao`):

| E-mail | Perfil |
| --- | --- |
| admin@alunostech.dev | Administrador |
| gerente@alunostech.dev | Gerente |
| dev@alunostech.dev | Desenvolvedor |
| cliente@alfa.example | Cliente (Mercado Alfa) |

### Kubernetes local

```powershell
powershell -ExecutionPolicy Bypass -File infra/scripts/deploy.ps1
kubectl -n alunostech get pods,svc,hpa
```

### Testes e roteiros de evidência

```powershell
dotnet test tests/AlunosTech.Domain.Tests
cd mobile/alunostech_mobile; flutter analyze; flutter test
powershell -File infra/scripts/evidencias-api.ps1 -Base http://localhost:5080
powershell -File infra/scripts/evidencias-concorrencia.ps1
sqlcmd -S localhost -U sa -P <senha> -C -d AlunosTech -i database/performance/02_demos_banco.sql
sqlcmd -S localhost -U sa -P <senha> -C -d AlunosTech -i database/performance/05_comparativo.sql
```

## Principais endpoints

| Método | Rota | Perfil |
| --- | --- | --- |
| POST | `/api/auth/login` | público (rate limit) |
| GET | `/api/projetos/{id}/tarefas` | autenticado |
| PATCH | `/api/tarefas/{id}/mover` | Admin, Gerente, Dev (409 em conflito, 422 em transição inválida) |
| GET / POST | `/api/chamados` | autenticado (Cliente vê só os próprios, via RLS) |
| POST | `/api/sprints/{id}/fechar` | Admin, Gerente |
| GET | `/api/relatorios/horas-por-projeto` | Admin, Gerente |
| POST | `/api/relatorios/fechar-mes/{ano}/{mes}` | Admin |
| GET | `/health/live`, `/health/ready`, `/metrics` | público |

## O que foi e o que não foi validado

Validado por execução: 27 testes .NET e 3 Flutter; scripts SQL aplicados em SQL Server 2022; roteiro funcional da API (local e no cluster kind); concorrência com duas sessões; otimização de consulta com 500 mil registros; build da imagem Docker; telas web, desktop e mobile (este em navegador).

**Não validado / proposto:** execução dos workflows no GitHub Actions (e varreduras Trivy/gitleaks), HPA com métricas (falta `metrics-server`), Prometheus/Grafana, aplicação efetiva da `NetworkPolicy`, execução do app em dispositivo Android e implantação em nuvem pública.

Em desenvolvimento a API conecta com o usuário `sa`; em produção deve usar o papel `role_alunostech_app` criado em `database/security/040_seguranca.sql`.
