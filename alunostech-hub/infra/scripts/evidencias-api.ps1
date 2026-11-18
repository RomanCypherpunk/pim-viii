# Roteiro de evidencias funcionais da API. Gera saida legivel para docs/evidencias.
# Uso: powershell -File infra/scripts/evidencias-api.ps1 -Base http://localhost:5080
param([string]$Base = 'http://localhost:5080', [string]$Senha = 'AlunosTech@2026')
$ErrorActionPreference = 'Continue'

function Chamar($metodo, $rota, $corpo = $null, $token = $null) {
    $h = @{}; if ($token) { $h['Authorization'] = "Bearer $token" }
    try {
        $p = @{ Uri = "$Base$rota"; Method = $metodo; Headers = $h; UseBasicParsing = $true; ContentType = 'application/json' }
        if ($corpo) { $p.Body = ($corpo | ConvertTo-Json -Depth 5) }
        $r = Invoke-WebRequest @p
        [pscustomobject]@{ Status = [int]$r.StatusCode; Corpo = $r.Content }
    } catch {
        $resp = $_.Exception.Response
        $txt = ''; if ($resp) { $txt = (New-Object IO.StreamReader($resp.GetResponseStream())).ReadToEnd() }
        [pscustomobject]@{ Status = [int]$resp.StatusCode; Corpo = $txt }
    }
}
function Passo($titulo, $r) { "[{0}] HTTP {1}`n    {2}`n" -f $titulo, $r.Status, ($r.Corpo -replace '"accessToken":"[^"]+"', '"accessToken":"<jwt>"') }

"=== EVIDENCIAS FUNCIONAIS DA API ($(Get-Date -Format 's')) ===`n"

# 1. Autenticacao
$ruim = Chamar POST '/api/auth/login' @{ email = 'admin@alunostech.dev'; senha = 'errada' }
Passo '1. Login com senha errada' $ruim
$tokens = @{}
foreach ($u in 'admin@alunostech.dev','gerente@alunostech.dev','dev@alunostech.dev','cliente@alfa.example') {
    $r = Chamar POST '/api/auth/login' @{ email = $u; senha = $Senha }
    $tokens[$u] = ($r.Corpo | ConvertFrom-Json).accessToken
    Passo "2. Login $u" $r
}
$adm = $tokens['admin@alunostech.dev']; $ger = $tokens['gerente@alunostech.dev']
$dev = $tokens['dev@alunostech.dev'];   $cli = $tokens['cliente@alfa.example']

# 2. Autorizacao por perfil
Passo '3. Sem token -> listar tarefas' (Chamar GET '/api/projetos/1/tarefas')
Passo '4. Cliente tenta fechar sprint (perfil sem permissao)' (Chamar POST '/api/sprints/1/fechar' $null $cli)

# 3. Kanban + ROWVERSION
$lista = (Chamar GET '/api/projetos/1/tarefas' $null $dev).Corpo | ConvertFrom-Json
$t = $lista | Where-Object { $_.titulo -eq 'Filtro por categoria' }   # Estado 2 (EmAndamento)
"Tarefa alvo: id=$($t.id) '$($t.titulo)' estado=$($t.estado)`n"
$ok = Chamar PATCH "/api/tarefas/$($t.id)/mover" @{ novoEstado = 3; rowVersion = $t.rowVersion } $dev
Passo '5. Mover EmAndamento -> EmRevisao (valido)' $ok
$inv = Chamar PATCH "/api/tarefas/$($t.id)/mover" @{ novoEstado = 0; rowVersion = ($ok.Corpo | ConvertFrom-Json).rowVersion } $dev
Passo '6. Mover EmRevisao -> Backlog (transicao invalida, regra de dominio)' $inv
# Conflito: segundo usuario usa o RowVersion antigo (lido antes da primeira alteracao)
$conf = Chamar PATCH "/api/tarefas/$($t.id)/mover" @{ novoEstado = 3; rowVersion = $t.rowVersion } $ger
Passo '7. Segundo usuario com RowVersion obsoleto (concorrencia otimista -> 409)' $conf
$novoRv = ($ok.Corpo | ConvertFrom-Json).rowVersion
Passo '8. Concluir tarefa (dispara evento de dominio + trigger de auditoria)' (Chamar PATCH "/api/tarefas/$($t.id)/mover" @{ novoEstado = 4; rowVersion = $novoRv } $dev)

# 4. Chamados + SLA + RLS
Passo '9. Cliente Alfa abre chamado critico (SLA calculado no banco)' (Chamar POST '/api/chamados' @{ clienteId = 1; titulo = 'Sistema fora do ar'; descricao = 'Pedidos nao carregam'; prioridade = 1 } $cli)
Passo '10. Cliente Alfa tenta abrir chamado em nome de outro cliente' (Chamar POST '/api/chamados' @{ clienteId = 2; titulo = 'Fraude'; prioridade = 3 } $cli)
Passo '11. Gerente abre chamado do cliente 2' (Chamar POST '/api/chamados' @{ clienteId = 2; titulo = 'Duvida no app'; prioridade = 3 } $ger)
Passo '12. Gerente lista chamados (ve todos os clientes)' (Chamar GET '/api/chamados' $null $ger)
Passo '13. Cliente Alfa lista chamados (RLS no banco filtra so os dele)' (Chamar GET '/api/chamados' $null $cli)

# 5. Sprint e fechamento mensal
Passo '14. Gerente fecha a Sprint 1 (transacao: velocity + devolve pendentes ao backlog)' (Chamar POST '/api/sprints/1/fechar' $null $ger)
Passo '15. Segundo fechamento da mesma sprint (rejeitado)' (Chamar POST '/api/sprints/1/fechar' $null $ger)
Passo '16. Relatorio de horas (periodo invalido -> 422)' (Chamar GET '/api/relatorios/horas-por-projeto?de=2026-12-01&ate=2026-01-01' $null $ger)
Passo '17. Dev tenta relatorio (sem permissao -> 403)' (Chamar GET '/api/relatorios/horas-por-projeto?de=2026-01-01&ate=2026-12-31' $null $dev)
Passo '18. Admin fecha horas de out/2026' (Chamar POST '/api/relatorios/fechar-mes/2026/10' $null $adm)
Passo '19. Admin repete o fechamento (idempotencia -> rejeitado)' (Chamar POST '/api/relatorios/fechar-mes/2026/10' $null $adm)
Passo '20. Health ready' (Chamar GET '/health/ready')
