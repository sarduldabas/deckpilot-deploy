# Creates the six GitHub repos and pushes each folder (needs GitHub CLI: winget install GitHub.cli, then `gh auth login`).
#   .\deckpilot-deploy\scripts\push-all.ps1 -GitHubUser <your-username>
# Re-running is safe: repos that already have an 'origin' just get a push.
param(
    [Parameter(Mandatory = $true)][string]$GitHubUser,
    [ValidateSet("public", "private")][string]$Visibility = "public"
)
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$repos = "project-service", "intake-service", "research-service", "builder-service", "deckpilot-ui", "deckpilot-deploy"

foreach ($repo in $repos) {
    Push-Location (Join-Path $root $repo)
    if (-not (Test-Path ".git")) { git init -b main | Out-Null }
    git add -A
    git commit -m "DeckPilot: $repo" *> $null
    git remote get-url origin *> $null
    if ($LASTEXITCODE -eq 0) {
        git push -u origin main
    } else {
        gh repo create "$GitHubUser/$repo" "--$Visibility" --source . --remote origin --push
    }
    Pop-Location
}
Write-Host "Done. Repos: https://github.com/$GitHubUser?tab=repositories" -ForegroundColor Green
