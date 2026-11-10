# Deploys DeckPilot to the current kubectl context (minikube):
# namespace -> config -> secrets -> every service's own k8s/ folder -> wait for rollouts.
param([string]$Namespace = "deckpilot")
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$k8s = Join-Path $root "deckpilot-deploy\k8s"

kubectl apply -f "$k8s\namespace.yaml"
kubectl apply -f "$k8s\configmap.yaml"
& "$PSScriptRoot\create-secrets.ps1" -Namespace $Namespace
& "$PSScriptRoot\sync-config.ps1" -Namespace $Namespace -NoRestart   # applies deckpilot-deploy\.env

foreach ($svc in "project-service", "intake-service", "research-service", "builder-service", "deckpilot-ui") {
    kubectl apply -f (Join-Path $root "$svc\k8s")
}

foreach ($d in "postgres", "project-service", "intake-service", "research-service", "builder-service", "deckpilot-ui") {
    kubectl rollout status "deployment/$d" -n $Namespace --timeout=240s
}

kubectl get pods -n $Namespace
Write-Host ""
Write-Host "Open the UI with:   minikube service deckpilot-ui -n $Namespace" -ForegroundColor Green
Write-Host "Dashboard:          minikube dashboard"
