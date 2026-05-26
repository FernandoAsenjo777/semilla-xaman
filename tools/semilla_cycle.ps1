param(
    [switch]$Loop,
    [int]$EverySeconds = 60,
    [int]$MaxIdleCycles = 3,
    [string]$SourceId = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Repo

function Get-Stamp {
    return Get-Date -Format "yyyyMMdd-HHmmss"
}

function Write-SemillaStatus {
    param(
        [string]$Status,
        [string]$Message,
        [int]$IdleCycles = 0
    )

    New-Item -ItemType Directory -Force -Path "runtime\status" | Out-Null

    $Payload = [ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        status = $Status
        message = $Message
        idle_cycles = $IdleCycles
        dangerous_actions_executed = $false
        repo = $Repo
    }

    $Payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "runtime\status\semilla_cycle_status.json" -Encoding UTF8
}

function Save-CycleEvidence {
    param(
        [string]$Status,
        [string]$Message,
        [int]$IdleCycles = 0
    )

    New-Item -ItemType Directory -Force -Path "evidence\cycle" | Out-Null
    $Stamp = Get-Stamp

    $Payload = [ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        status = $Status
        message = $Message
        idle_cycles = $IdleCycles
        dangerous_actions_executed = $false
        repo = $Repo
    }

    $Path = "evidence\cycle\semilla_cycle_status_$Stamp.json"
    $Payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Commit-SafeArtifacts {
    param(
        [string]$Message
    )

    git add README.md docs data tools runtime evidence 2>$null

    $Changes = git diff --cached --name-only
    if (![string]::IsNullOrWhiteSpace($Changes)) {
        git commit -m $Message
        git push origin main
        Write-Host "[SEMILLA-CYCLE] Commit/push OK"
    } else {
        Write-Host "[SEMILLA-CYCLE] No changes to commit"
    }
}

function Invoke-LearningHarness {
    param(
        [string]$SourceId
    )

    if ([string]::IsNullOrWhiteSpace($SourceId)) {
        $Output = python .\tools\semilla_learning_harness.py 2>&1
    } else {
        $Output = python .\tools\semilla_learning_harness.py --source-id $SourceId 2>&1
    }

    $TextOutput = ($Output | Out-String).Trim()

    if ($TextOutput) {
        Write-Host $TextOutput
    }

    return [ordered]@{
        exit_code = $LASTEXITCODE
        output = $TextOutput
    }
}

function Run-One-Cycle {
    param(
        [int]$CurrentIdleCycles = 0
    )

    $Stamp = Get-Stamp

    Write-Host "[$Stamp][SEMILLA-CYCLE] Repo: $Repo"
    Write-Host "[$Stamp][SEMILLA-CYCLE] Pull..."
    git pull origin main

    $Pending = @(Get-ChildItem -Path "runtime\inbox" -Filter "*.md" -File -ErrorAction SilentlyContinue)

    if ($Pending.Count -eq 0) {
        Write-Host "[$Stamp][SEMILLA-CYCLE] No pending task. Creating learning task..."

        $Harness = Invoke-LearningHarness -SourceId $SourceId

        if ($Harness.exit_code -ne 0) {
            if ($Harness.output -match "No hay fuentes pendientes") {
                $NewIdleCycles = $CurrentIdleCycles + 1
                $Msg = "No hay fuentes pendientes nuevas en source_map."

                Write-Host "[$Stamp][SEMILLA-CYCLE] IDLE_DONE: $Msg"
                Write-SemillaStatus -Status "IDLE_DONE" -Message $Msg -IdleCycles $NewIdleCycles
                Save-CycleEvidence -Status "IDLE_DONE" -Message $Msg -IdleCycles $NewIdleCycles
                Commit-SafeArtifacts -Message "chore: semilla cycle idle done $Stamp"

                return [ordered]@{
                    status = "IDLE_DONE"
                    idle_cycles = $NewIdleCycles
                    should_continue = $false
                }
            }

            $Err = "learning_harness failed with code $($Harness.exit_code)"
            Write-SemillaStatus -Status "ERROR_REAL" -Message $Err -IdleCycles $CurrentIdleCycles
            Save-CycleEvidence -Status "ERROR_REAL" -Message $Err -IdleCycles $CurrentIdleCycles
            throw $Err
        }
    } else {
        Write-Host "[$Stamp][SEMILLA-CYCLE] Pending task exists: $($Pending[0].Name)"
    }

    $PendingAfter = @(Get-ChildItem -Path "runtime\inbox" -Filter "*.md" -File -ErrorAction SilentlyContinue)

    if ($PendingAfter.Count -eq 0) {
        $Msg = "No se creó ninguna tarea nueva."
        Write-Host "[$Stamp][SEMILLA-CYCLE] IDLE_DONE: $Msg"
        Write-SemillaStatus -Status "IDLE_DONE" -Message $Msg -IdleCycles ($CurrentIdleCycles + 1)
        Save-CycleEvidence -Status "IDLE_DONE" -Message $Msg -IdleCycles ($CurrentIdleCycles + 1)
        Commit-SafeArtifacts -Message "chore: semilla cycle idle done $Stamp"

        return [ordered]@{
            status = "IDLE_DONE"
            idle_cycles = ($CurrentIdleCycles + 1)
            should_continue = $false
        }
    }

    Write-Host "[$Stamp][SEMILLA-CYCLE] Running Qwen bridge..."
    python .\tools\semilla_qwen_bridge.py

    if ($LASTEXITCODE -ne 0) {
        $Err = "qwen_bridge failed with code $LASTEXITCODE"
        Write-SemillaStatus -Status "ERROR_REAL" -Message $Err -IdleCycles $CurrentIdleCycles
        Save-CycleEvidence -Status "ERROR_REAL" -Message $Err -IdleCycles $CurrentIdleCycles
        throw $Err
    }

    Write-Host "[$Stamp][SEMILLA-CYCLE] Git add/commit/push safe artifacts..."
    Commit-SafeArtifacts -Message "chore: semilla learning cycle $Stamp"

    Write-SemillaStatus -Status "OK" -Message "Cycle finished OK." -IdleCycles 0
    Save-CycleEvidence -Status "OK" -Message "Cycle finished OK." -IdleCycles 0

    Write-Host "[$Stamp][SEMILLA-CYCLE] Finished OK"

    return [ordered]@{
        status = "OK"
        idle_cycles = 0
        should_continue = $true
    }
}

if ($Loop) {
    Write-Host "[SEMILLA-CYCLE] Loop mode ON. Every $EverySeconds seconds. Max idle cycles: $MaxIdleCycles. CTRL+C to stop."

    $IdleCycles = 0

    while ($true) {
        try {
            $Result = Run-One-Cycle -CurrentIdleCycles $IdleCycles
            $IdleCycles = [int]$Result.idle_cycles

            if ($Result.status -eq "IDLE_DONE") {
                Write-Host "[SEMILLA-CYCLE] IDLE_DONE detected."

                if ($IdleCycles -ge $MaxIdleCycles) {
                    Write-Host "[SEMILLA-CYCLE] Max idle cycles reached ($IdleCycles/$MaxIdleCycles). Stopping loop cleanly."
                    Write-SemillaStatus -Status "STOPPED_IDLE_DONE" -Message "Loop stopped after max idle cycles." -IdleCycles $IdleCycles
                    Save-CycleEvidence -Status "STOPPED_IDLE_DONE" -Message "Loop stopped after max idle cycles." -IdleCycles $IdleCycles
                    Commit-SafeArtifacts -Message "chore: semilla loop stopped idle done $(Get-Stamp)"
                    break
                }
            }

        } catch {
            $Msg = $_.Exception.Message
            Write-Host "[SEMILLA-CYCLE][ERROR_REAL] $Msg"
            Write-SemillaStatus -Status "ERROR_REAL" -Message $Msg -IdleCycles $IdleCycles
            Save-CycleEvidence -Status "ERROR_REAL" -Message $Msg -IdleCycles $IdleCycles
            Commit-SafeArtifacts -Message "chore: semilla cycle error real $(Get-Stamp)"
            break
        }

        Write-Host "[SEMILLA-CYCLE] Waiting $EverySeconds seconds..."
        Start-Sleep -Seconds $EverySeconds
    }

    Write-Host "[SEMILLA-CYCLE] Loop finished."
} else {
    $null = Run-One-Cycle -CurrentIdleCycles 0
}
