# Teste de carga para demonstrar o autoescalonamento (HPA). Requer o cluster do deploy.ps1 e o metrics-server.
# Uso: powershell -File infra/scripts/load-test.ps1 [-Minutos 5] [-Saida docs/evidencias/k8s-hpa-carga.txt]
param([int]$Minutos = 5, [string]$Saida = 'docs/evidencias/k8s-hpa-carga.txt', [string]$Senha = 'AlunosTech@2026')
$ErrorActionPreference = 'Continue'
$ns = 'alunostech'

# 1) token JWT via port-forward temporario
$pf = Start-Process kubectl -ArgumentList '-n', $ns, 'port-forward', 'svc/api', '5099:80' -PassThru -WindowStyle Hidden
Start-Sleep 5
$login = Invoke-RestMethod -Method Post -Uri 'http://localhost:5099/api/auth/login' -ContentType 'application/json' `
    -Body (@{ email = 'gerente@alunostech.dev'; senha = $Senha } | ConvertTo-Json)
Stop-Process -Id $pf.Id -Force
$token = $login.accessToken

# 2) geradores de carga dentro do cluster (busybox), varios processos por pod
$yaml = @"
apiVersion: apps/v1
kind: Deployment
metadata: { name: load, namespace: $ns }
spec:
  replicas: 4
  selector: { matchLabels: { app: load } }
  template:
    metadata: { labels: { app: load } }
    spec:
      containers:
        - name: load
          image: busybox:1.36
          imagePullPolicy: IfNotPresent
          env: [{ name: T, value: "$token" }]
          command: ["/bin/sh", "-c"]
          args:
            - |
              for i in 1 2 3 4 5 6; do
                ( while true; do wget -q -O /dev/null --header "Authorization: Bearer `$T" http://api/api/projetos/1/tarefas; done ) &
              done
              wait
"@
$yaml | kubectl apply -f - | Out-Null

# 3) amostragem do HPA e dos pods
$saidaCompleta = Join-Path (Get-Location) $Saida
"=== Teste de carga: $Minutos min, inicio $(Get-Date -Format s) ===" | Out-File $saidaCompleta -Encoding utf8
$fim = (Get-Date).AddMinutes($Minutos)
while ((Get-Date) -lt $fim) {
    $h = kubectl -n $ns get hpa api --no-headers 2>&1
    $p = (kubectl -n $ns get pods -l app=api --no-headers 2>&1 | Measure-Object).Count
    "{0}  pods-api={1}  {2}" -f (Get-Date -Format 'HH:mm:ss'), $p, ($h -replace '\s+', ' ') | Tee-Object -FilePath $saidaCompleta -Append
    Start-Sleep 20
}

# 4) encerra a carga e registra o estado final
kubectl -n $ns delete deployment load | Out-Null
"--- carga encerrada $(Get-Date -Format s) ---" | Out-File $saidaCompleta -Append -Encoding utf8
kubectl -n $ns get hpa,pods 2>&1 | Out-File $saidaCompleta -Append -Encoding utf8
