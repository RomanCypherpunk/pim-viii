# Sobe o ambiente Kubernetes local (kind) e faz o deploy. Requer Docker Desktop, kind e kubectl.
# Uso:  powershell -ExecutionPolicy Bypass -File infra/scripts/deploy.ps1
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root

if (-not (kind get clusters | Select-String '^alunostech$')) { kind create cluster --name alunostech }
docker build -f infra/docker/Dockerfile.api -t alunostech-api:latest .
kind load docker-image alunostech-api:latest --name alunostech

kubectl apply -f infra/k8s/alunostech.yaml
$sa  = if ($env:MSSQL_SA_PASSWORD) { $env:MSSQL_SA_PASSWORD } else { 'Local#Pass2026Strong!' }
$jwt = if ($env:JWT_KEY) { $env:JWT_KEY } else { -join ((48..57 + 97..122) | Get-Random -Count 48 | ForEach-Object { [char]$_ }) }
kubectl -n alunostech delete secret alunostech-secrets --ignore-not-found
kubectl -n alunostech create secret generic alunostech-secrets --from-literal=sa-password=$sa --from-literal=jwt-key=$jwt

kubectl -n alunostech rollout status statefulset/sqlserver --timeout=300s
kubectl -n alunostech rollout restart deployment/api
kubectl -n alunostech rollout status deployment/api --timeout=300s
kubectl -n alunostech get pods,svc,hpa
