# Builds all five images INSIDE minikube's Docker daemon, so no registry is needed.
# Run from anywhere:  .\deckpilot-deploy\scripts\build-images.ps1
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

& minikube -p minikube docker-env --shell powershell | Invoke-Expression

$images = "project-service", "intake-service", "research-service", "builder-service", "deckpilot-ui"
foreach ($name in $images) {
    Write-Host "Building $name ..." -ForegroundColor Cyan
    docker build -t "deckpilot/${name}:1.0" (Join-Path $root $name)
    if ($LASTEXITCODE -ne 0) { throw "docker build failed for $name" }
}
Write-Host "All images built inside minikube." -ForegroundColor Green
