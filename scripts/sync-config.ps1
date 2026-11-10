# Pushes deckpilot-deploy\.env into the Kubernetes cluster and restarts the services:
#   - non-secret settings (models, reasoning levels, quality knobs)  -> ConfigMap deckpilot-config
#   - AZURE_OPENAI_ENDPOINT / AZURE_OPENAI_API_KEY / AZURE_OPENAI_DEPLOYMENT -> Secret azure-openai
# Run it after every change to .env.   Usage:  .\deckpilot-deploy\scripts\sync-config.ps1
param(
    [string]$Namespace = "deckpilot",
    [switch]$NoRestart
)
$envFile = Join-Path $PSScriptRoot "..\.env"
$cfg = @{}
if (Test-Path $envFile) {
    foreach ($raw in Get-Content $envFile) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith("#") -or -not $line.Contains("=")) { continue }
        $k, $v = $line.Split("=", 2)
        $v = $v.Trim()
        if ($v.Length -ge 2 -and (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'")))) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        $cfg[$k.Trim()] = $v
    }
} else {
    Write-Host ".env not found - using defaults (mock mode)." -ForegroundColor Yellow
}

$secretKeys = @("AZURE_OPENAI_ENDPOINT", "AZURE_OPENAI_API_KEY", "AZURE_OPENAI_DEPLOYMENT")
$final = [ordered]@{
    LLM_PROVIDER = "mock"; LLM_REASONING_EFFORT = "low"; BUILDER_REASONING_EFFORT = "medium"
    LLM_TIMEOUT = "180"; MAX_QUERIES = "6"; ENABLE_IMAGES = "true"; DEFAULT_THEME = "executive"
    INTAKE_TIMEOUT = "120"; RESEARCH_TIMEOUT = "600"; BUILD_TIMEOUT = "420"
}
foreach ($k in $cfg.Keys) {
    if ($secretKeys -contains $k) { continue }
    if ($cfg[$k] -ne "") { $final[$k] = $cfg[$k] }          # blank value = keep the default
}
$final["POSTGRES_HOST"] = "postgres"; $final["POSTGRES_PORT"] = "5432"
$final["INTAKE_URL"] = "http://intake-service:8000"
$final["RESEARCH_URL"] = "http://research-service:8000"
$final["BUILDER_URL"] = "http://builder-service:8000"

$cmArgs = @("create", "configmap", "deckpilot-config", "-n", $Namespace)
foreach ($k in $final.Keys) { $cmArgs += "--from-literal=$k=$($final[$k])" }
$cmArgs += @("--dry-run=client", "-o", "yaml")
& kubectl @cmArgs | kubectl apply -f -
Write-Host "ConfigMap deckpilot-config updated (LLM_PROVIDER=$($final['LLM_PROVIDER']))." -ForegroundColor Green

function Test-Set($name) { return $cfg[$name] -and -not $cfg[$name].Contains("<") }
if ((Test-Set "AZURE_OPENAI_ENDPOINT") -and (Test-Set "AZURE_OPENAI_API_KEY") -and (Test-Set "AZURE_OPENAI_DEPLOYMENT")) {
    kubectl create secret generic azure-openai -n $Namespace `
        --from-literal=AZURE_OPENAI_ENDPOINT=$($cfg["AZURE_OPENAI_ENDPOINT"]) `
        --from-literal=AZURE_OPENAI_API_KEY=$($cfg["AZURE_OPENAI_API_KEY"]) `
        --from-literal=AZURE_OPENAI_DEPLOYMENT=$($cfg["AZURE_OPENAI_DEPLOYMENT"]) `
        --dry-run=client -o yaml | kubectl apply -f -
    Write-Host "Secret azure-openai updated from .env." -ForegroundColor Green
} elseif ($final["LLM_PROVIDER"] -eq "azure") {
    throw "LLM_PROVIDER=azure but AZURE_OPENAI_ENDPOINT / AZURE_OPENAI_API_KEY / AZURE_OPENAI_DEPLOYMENT are not all filled in .env"
} else {
    Write-Host "No Azure values in .env - secret azure-openai left unchanged (mock mode)." -ForegroundColor Yellow
}

if (-not $NoRestart) {
    $deployments = "intake-service", "research-service", "builder-service", "project-service"
    kubectl rollout restart ($deployments | ForEach-Object { "deployment/$_" }) -n $Namespace
    foreach ($d in $deployments) { kubectl rollout status "deployment/$d" -n $Namespace --timeout=180s }
    Write-Host "Services restarted with the new configuration." -ForegroundColor Green
}
