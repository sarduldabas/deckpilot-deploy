# Switches the agents between offline mock data and Microsoft Foundry.
# It edits LLM_PROVIDER in deckpilot-deploy\.env and runs sync-config.ps1.
#   .\deckpilot-deploy\scripts\use-mode.ps1 -Mode azure
#   .\deckpilot-deploy\scripts\use-mode.ps1 -Mode mock
param(
    [Parameter(Mandatory = $true)][ValidateSet("mock", "azure")][string]$Mode,
    [string]$Namespace = "deckpilot"
)
$envFile = Join-Path $PSScriptRoot "..\.env"
if (-not (Test-Path $envFile)) { throw ".env not found. Copy .env.example to .env and fill it in first." }
$lines = Get-Content $envFile
if ($lines -match '^\s*LLM_PROVIDER\s*=') {
    $lines = $lines -replace '^\s*LLM_PROVIDER\s*=.*$', "LLM_PROVIDER=$Mode"
} else {
    $lines = @("LLM_PROVIDER=$Mode") + $lines
}
Set-Content -Path $envFile -Value $lines
& "$PSScriptRoot\sync-config.ps1" -Namespace $Namespace
Write-Host "LLM_PROVIDER is now '$Mode'." -ForegroundColor Green
