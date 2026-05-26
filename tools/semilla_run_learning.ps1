$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Repo

Write-Host "[SEMILLA-LEARNING] Repo: $Repo"

python .\tools\semilla_learning_harness.py @args
if ($LASTEXITCODE -ne 0) {
    throw "semilla_learning_harness.py falló con código $LASTEXITCODE"
}

git status --short
git add tools runtime evidence

$Changes = git diff --cached --name-only
if (![string]::IsNullOrWhiteSpace($Changes)) {
    $Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    git commit -m "feat: create semilla learning task $Stamp"
    git push origin main
    Write-Host "[SEMILLA-LEARNING] Commit/push OK"
} else {
    Write-Host "[SEMILLA-LEARNING] No changes to commit"
}

Write-Host "[SEMILLA-LEARNING] Finished OK"
