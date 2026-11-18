# EXECUTE COMO ADMINISTRADOR (PowerShell > "Executar como administrador").
# Instala o que o PIM VIII exige e que ainda nao esta na maquina: SQL Server (banco) e Docker/Kubernetes.
# Etapa 1: SQL Server Express (nao exige reinicio).
# Etapa 2: WSL2 + Docker Desktop + kubectl + kind (exige REINICIAR o Windows ao terminar).
$ErrorActionPreference = 'Stop'

winget install --id Microsoft.SQLServer.2022.Express --accept-package-agreements --accept-source-agreements `
  --override '/Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=Install /FEATURES=SQLEngine /INSTANCENAME=MSSQLSERVER /SECURITYMODE=SQL /SAPWD="AlunosTech#2026Strong!" /TCPENABLED=1 /SQLSYSADMINACCOUNTS="BUILTIN\Administrators"'
winget install --id Microsoft.Sqlcmd --accept-package-agreements --accept-source-agreements

wsl --install --no-distribution
winget install --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
winget install --id Kubernetes.kubectl --accept-package-agreements --accept-source-agreements
winget install --id Kubernetes.kind --accept-package-agreements --accept-source-agreements

Write-Host "`nConcluido. REINICIE o Windows, abra o Docker Desktop uma vez (aceite os termos)." -ForegroundColor Green

