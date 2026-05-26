param(
    [switch]$Loop,
    [int]$EverySeconds = 60,
    [string]$SourceId = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Repo

function Write-JsonStatus {
    param(
        [string]$Status,
        [string]$Message
    )

    New-Item -ItemType Directory -Force -Path "runtime\status" | Out-Null

    $Payload = [ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        status = $Status
        message = $Message
        dangerous_actions_executed = $false
    }

    $Payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "runtime\status\semilla_cycle_status.json" -Encoding UTF8
}

function Run-One-Cycle {
    $Stamp = Get-Date -Format "yyyyMMdd-HHmmss"

    Write-Host "[$Stamp][SEMILLA-CYCLE] Repo: $Repo"
    Write-Host "[$Stamp][SEMILLA-CYCLE] Pull..."
    git pull origin main

    $Pending = @(Get-ChildItem -Path "runtime\inbox" -Filter "*.md" -File -ErrorAction SilentlyContinue)
    $CreatedTask = $false

    if ($Pending.Count -eq 0) {
        Write-Host "[$Stamp][SEMILLA-CYCLE] No pending task. Creating learning task..."

        if ([string]::IsNullOrWhiteSpace($SourceId)) {
            $Output = python .\tools\semilla_learning_harness.py 2>&1
        } else {
            $Output = python .\tools\semilla_learning_harness.py --source-id $SourceId 2>&1
        }

        $TextOutput = ($Output | Out-String).Trim()
        if ($TextOutput) {
            Write-Host $TextOutput
        }

        if ($LASTEXITCODE -ne 0) {
            if ($TextOutput -match "No hay fuentes pendientes") {
                Write-Host "[$Stamp][SEMILLA-CYCLE] IDLE: no hay fuentes pendientes nuevas."
                Write-JsonStatus -Status "IDLE_NO_PENDING_SOURCES" -Message "No hay fuentes pendientes nuevas en source_map."

                git add runtime\status\semilla_cycle_status.json
                $Changes = git diff --cached --name-only

                if (![string]::IsNullOrWhiteSpace($Changes)) {
                    git commit -m "chore: semilla cycle idle no pending sources $Stamp"
                    git push origin main
                    Write-Host "[$Stamp][SEMILLA-CYCLE] IDLE status commit/push OK"
                }

                return
            }

            throw "learning_harness failed with code $LASTEXITCODE"
        }

        $CreatedTask = $true
    } else {
        Write-Host "[$Stamp][SEMILLA-CYCLE] Pending task exists: $($Pending[0].Name)"
        $CreatedTask = $true
    }

    $PendingAfter = @(Get-ChildItem -Path "runtime\inbox" -Filter "*.md" -File -ErrorAction SilentlyContinue)

    if ($PendingAfter.Count -eq 0) {
        Write-Host "[$Stamp][SEMILLA-CYCLE] IDLE: no task created."
        Write-JsonStatus -Status "IDLE_NO_TASK_CREATED" -Message "No se creó ninguna tarea nueva."
        return
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

    Write-JsonStatus -Status "OK" -Message "Cycle finished OK."
    Write-Host "[$Stamp][SEMILLA-CYCLE] Finished OK"
}

if ($Loop) {
    Write-Host "[SEMILLA-CYCLE] Loop mode ON. Every $EverySeconds seconds. CTRL+C to stop."

    while ($true) {
        try {
            Run-One-Cycle
        } catch {
            Write-Host "[SEMILLA-CYCLE][ERROR] $($_.Exception.Message)"
            Write-JsonStatus -Status "ERROR" -Message $_.Exception.Message
        }

        Write-Host "[SEMILLA-CYCLE] Waiting $EverySeconds seconds..."
        Start-Sleep -Seconds $EverySeconds
    }
} else {
    Run-One-Cycle
}
