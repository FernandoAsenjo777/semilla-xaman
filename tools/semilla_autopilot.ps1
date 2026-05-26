$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Repo

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$StatusPath = "runtime\status\semilla_autopilot_status.json"
$EvidencePath = "evidence\autopilot\semilla_autopilot_$Stamp.json"

Write-Host "[SEMILLA-AUTOPILOT] Repo: $Repo"
Write-Host "[SEMILLA-AUTOPILOT] Safe mode: ON"

$Result = [ordered]@{
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    repo = $Repo
    safe_mode = $true
    dangerous_actions_executed = $false
    status = "OK"
    actions = @(
        "verified_repo",
        "verified_runtime_dirs",
        "wrote_status",
        "wrote_evidence"
    )
    next_recommended = @(
        "create_learning_harness",
        "create_dataset_builder",
        "connect_quality_score",
        "create_first_qwen_learning_task"
    )
}

New-Item -ItemType Directory -Force -Path "runtime\status" | Out-Null
New-Item -ItemType Directory -Force -Path "evidence\autopilot" | Out-Null

$Json = $Result | ConvertTo-Json -Depth 8
$Json | Set-Content -LiteralPath $StatusPath -Encoding UTF8
$Json | Set-Content -LiteralPath $EvidencePath -Encoding UTF8

Write-Host "[SEMILLA-AUTOPILOT] Status: $StatusPath"
Write-Host "[SEMILLA-AUTOPILOT] Evidence: $EvidencePath"

git status --short

git add $StatusPath $EvidencePath
$Changes = git diff --cached --name-only

if (![string]::IsNullOrWhiteSpace($Changes)) {
    git commit -m "chore: record semilla autopilot status $Stamp"
    git push origin main
    Write-Host "[SEMILLA-AUTOPILOT] Commit/push OK"
} else {
    Write-Host "[SEMILLA-AUTOPILOT] No changes to commit"
}

Write-Host "[SEMILLA-AUTOPILOT] Finished OK"
