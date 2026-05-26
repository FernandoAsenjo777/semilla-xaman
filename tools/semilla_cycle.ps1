param(
    [switch]$Loop,
    [int]$EverySeconds = 60,
    [string]$SourceId = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Repo

function Run-One-Cycle {
    $Stamp = Get-Date -Format "yyyyMMdd-HHmmss"

    Write-Host "[$Stamp][SEMILLA-CYCLE] Repo: $Repo"
    Write-Host "[$Stamp][SEMILLA-CYCLE] Pull..."
    git pull origin main

    $Pending = @(Get-ChildItem -Path "runtime\inbox" -Filter "*.md" -File -ErrorAction SilentlyContinue)

    if ($Pending.Count -eq 0) {
        Write-Host "[$Stamp][SEMILLA-CYCLE] No pending task. Creating learning task..."
        if ([string]::IsNullOrWhiteSpace($SourceId)) {
            python .\tools\semilla_learning_harness.py
        } else {
            python .\tools\semilla_learning_harness.py --source-id $SourceId
        }

        if ($LASTEXITCODE -ne 0) {
            throw "learning_harness failed with code $LASTEXITCODE"
        }
    } else {
        Write-Host "[$Stamp][SEMILLA-CYCLE] Pending task exists: $($Pending[0].Name)"
    }

    Write-Host "[$Stamp][SEMILLA-CYCLE] Running Qwen bridge..."
    python .\tools\semilla_qwen_bridge.py
    if ($LASTEXITCODE -ne 0) {
        throw "qwen_bridge failed with code $LASTEXITCODE"
    }

    Write-Host "[$Stamp][SEMILLA-CYCLE] Git add/commit/push safe artifacts..."
    git add README.md docs data tools runtime evidence

    $Changes = git diff --cached --name-only
    if (![string]::IsNullOrWhiteSpace($Changes)) {
        git commit -m "chore: semilla learning cycle $Stamp"
        git push origin main
        Write-Host "[$Stamp][SEMILLA-CYCLE] Commit/push OK"
    } else {
        Write-Host "[$Stamp][SEMILLA-CYCLE] No changes to commit"
    }

    Write-Host "[$Stamp][SEMILLA-CYCLE] Finished OK"
}

if ($Loop) {
    Write-Host "[SEMILLA-CYCLE] Loop mode ON. Every $EverySeconds seconds. CTRL+C to stop."
    while ($true) {
        try {
            Run-One-Cycle
        } catch {
            Write-Host "[SEMILLA-CYCLE][ERROR] $($_.Exception.Message)"
        }
        Write-Host "[SEMILLA-CYCLE] Waiting $EverySeconds seconds..."
        Start-Sleep -Seconds $EverySeconds
    }
} else {
    Run-One-Cycle
}
