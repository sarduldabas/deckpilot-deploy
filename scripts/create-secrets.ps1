# Creates the Kubernetes Secrets. Nothing secret is stored in any repo.
#  - postgres-secret : created once with a random password (kept on re-runs so the DB keeps working)
#  - azure-openai    : created from deckpilot-deploy\.env by sync-config.ps1 (not here)
param([string]$Namespace = "deckpilot")

kubectl get secret postgres-secret -n $Namespace *> $null
if ($LASTEXITCODE -ne 0) {
    $pw = -join ((48..57) + (97..122) | Get-Random -Count 20 | ForEach-Object { [char]$_ })
    kubectl create secret generic postgres-secret -n $Namespace `
        --from-literal=POSTGRES_USER=deckpilot `
        --from-literal=POSTGRES_PASSWORD=$pw `
        --from-literal=POSTGRES_DB=deckpilot
    Write-Host "Created postgres-secret." -ForegroundColor Green
} else {
    Write-Host "postgres-secret already exists - keeping it."
}

Write-Host "The Azure key is applied from .env by sync-config.ps1 (called by deploy.ps1)." -ForegroundColor Cyan
