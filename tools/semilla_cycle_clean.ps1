param(
    [switch]$RunOnce,
    [switch]$Commit,
    [string]$Model = "qwen-local"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Repo

$StatusDir = "runtime\status"
$EvidenceDir = "evidence\cycle"
$InboxDir = "runtime\inbox"
$OutboxDir = "runtime\outbox"
$ProcessedDir = "runtime\processed"
$SourceMapPath = "data\source_map.json"

New-Item -ItemType Directory -Force -Path $StatusDir, $EvidenceDir, $InboxDir, $OutboxDir, $ProcessedDir | Out-Null

function Get-Stamp {
    return Get-Date -Format "yyyyMMdd-HHmmss"
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Data
    )

    $Data | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Write-State {
    param(
        [string]$Status,
        [string]$Message,
        [object]$Extra = $null
    )

    $Payload = [ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        status = $Status
        message = $Message
        repo = $Repo
        dangerous_actions_executed = $false
        extra = $Extra
    }

    Write-JsonFile -Path "$StatusDir\semilla_cycle_clean_status.json" -Data $Payload

    $Stamp = Get-Stamp
    Write-JsonFile -Path "$EvidenceDir\semilla_cycle_clean_$Stamp.json" -Data $Payload

    Write-Host "[SEMILLA-CLEAN][$Status] $Message"

    return $Payload
}

function Invoke-Git {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Args
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "git"
    foreach ($a in $Args) {
        [void]$psi.ArgumentList.Add($a)
    }
    $psi.WorkingDirectory = $Repo
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()

    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    if (![string]::IsNullOrWhiteSpace($stdout)) {
        Write-Host $stdout.Trim()
    }

    if (![string]::IsNullOrWhiteSpace($stderr)) {
        Write-Host $stderr.Trim()
    }

    if ($p.ExitCode -ne 0) {
        throw "git $($Args -join ' ') failed with exit code $($p.ExitCode)"
    }

    return [ordered]@{
        exit_code = $p.ExitCode
        stdout = $stdout
        stderr = $stderr
    }
}

function Commit-Safe {
    param(
        [string]$Message
    )

    Invoke-Git -Args @("add", "README.md", "docs", "data", "tools", "runtime", "evidence") | Out-Null

    $diff = Invoke-Git -Args @("diff", "--cached", "--name-only")
    $changed = $diff.stdout.Trim()

    if ([string]::IsNullOrWhiteSpace($changed)) {
        Write-Host "[SEMILLA-CLEAN] No changes to commit."
        return $false
    }

    Invoke-Git -Args @("commit", "-m", $Message) | Out-Null
    Invoke-Git -Args @("push", "origin", "main") | Out-Null

    Write-Host "[SEMILLA-CLEAN] Commit/push OK."
    return $true
}

function Get-ProcessedSourceIds {
    $ids = New-Object System.Collections.Generic.HashSet[string]

    if (Test-Path $ProcessedDir) {
        Get-ChildItem -Path $ProcessedDir -Filter "*.learning_task.md" -File -ErrorAction SilentlyContinue | ForEach-Object {
            $name = $_.BaseName
            $parts = $name -split "_", 2
            if ($parts.Count -eq 2) {
                [void]$ids.Add(($parts[1] -replace "\.learning_task$", ""))
            }
        }
    }

    if (Test-Path "runtime\memory\learning_events.jsonl") {
        Get-Content "runtime\memory\learning_events.jsonl" -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace($_)) { return }
            try {
                $event = $_ | ConvertFrom-Json
                if ($event.source_id) {
                    [void]$ids.Add([string]$event.source_id)
                }
            } catch {}
        }
    }

    return $ids
}

function Get-NextSource {
    if (!(Test-Path $SourceMapPath)) {
        throw "No existe $SourceMapPath"
    }

    $map = Get-Content -LiteralPath $SourceMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $processed = Get-ProcessedSourceIds

    $sources = @($map.sources)

    $priority = @{
        "alta" = 1
        "media-alta" = 2
        "media" = 3
        "baja" = 4
    }

    $pending = @(
        $sources | Where-Object {
            $id = [string]$_.id
            $status = [string]$_.status
            ($status.StartsWith("pendiente")) -and (-not $processed.Contains($id))
        } | Sort-Object {
            $p = [string]$_.priority
            if ($priority.ContainsKey($p)) { $priority[$p] } else { 99 }
        }
    )

    if ($pending.Count -eq 0) {
        return $null
    }

    return $pending[0]
}

function New-LearningTask {
    param(
        [Parameter(Mandatory=$true)]
        $Source
    )

    $Stamp = Get-Stamp
    $SourceId = [string]$Source.id
    $Modules = @($Source.modules) -join ", "
    $TaskPath = "$InboxDir\$($Stamp)_$($SourceId).learning_task.md"

    $Content = @"
# Microtarea de aprendizaje · $SourceId

## Objetivo

Destilar esta fuente para enseñar a Qwen Semilla.

## Fuente

- ID: $($Source.id)
- Fuente: $($Source.source)
- Tipo: $($Source.type)
- Enseña: $($Source.teaches)
- Pierna: $($Source.leg)
- Módulos inspirados: $Modules

## Preguntas cerradas

1. ¿Qué patrón principal debe aprender Qwen de esta fuente?
2. ¿Qué módulo debe mejorar?
3. ¿Qué riesgo hay si Qwen aplica mal este patrón?
4. ¿Qué regla concreta añadirías a la escuela de Qwen?
5. Veredicto: DESCARTAR / DESTILAR / PROBAR / INTEGRAR.

## Formato obligatorio

| Patrón aprendido | Módulo afectado | Riesgo | Regla para Qwen | Veredicto |
|---|---|---|---|---|

## Límites

No copies código externo.
No propongas instalaciones.
No conectes credenciales.
No inventes haber leído archivos que no se te han pasado.
No des teoría genérica.

## Criterio de éxito

La respuesta debe convertirse en aprendizaje guardable para Qwen Semilla.
"@

    $Content | Set-Content -LiteralPath $TaskPath -Encoding UTF8

    return $TaskPath
}

function Invoke-Qwen {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskPath
    )

    $Prompt = Get-Content -LiteralPath $TaskPath -Raw -Encoding UTF8

    $SystemPrompt = @"
Eres Qwen Semilla, una IA local en entrenamiento para evolucionar hacia Xaman local.
Responde con precisión, estructura y humildad operativa.
No inventes haber leído archivos externos.
No propongas acciones peligrosas.
Respeta exactamente el formato pedido.
Si falta información, dilo.
"@

    $FullPrompt = $SystemPrompt + "`n`n" + $Prompt

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "ollama"
    [void]$psi.ArgumentList.Add("run")
    [void]$psi.ArgumentList.Add($Model)
    [void]$psi.ArgumentList.Add($FullPrompt)
    $psi.WorkingDirectory = $Repo
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi

    [void]$p.Start()

    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()

    $finished = $p.WaitForExit(300000)

    if (-not $finished) {
        try { $p.Kill() } catch {}
        throw "Qwen timeout after 300 seconds"
    }

    if ($p.ExitCode -ne 0) {
        throw "ollama run failed with exit code $($p.ExitCode): $stderr"
    }

    return $stdout.Trim()
}

function Run-CleanCycle {
    Invoke-Git -Args @("pull", "origin", "main") | Out-Null

    $pendingTasks = @(Get-ChildItem -Path $InboxDir -Filter "*.md" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)

    if ($pendingTasks.Count -eq 0) {
        $nextSource = Get-NextSource

        if ($null -eq $nextSource) {
            Write-State -Status "IDLE_DONE" -Message "No hay tareas en inbox y no hay fuentes pendientes nuevas."
            if ($Commit) {
                Commit-Safe -Message "chore: semilla clean cycle idle done $(Get-Stamp)" | Out-Null
            }
            return "IDLE_DONE"
        }

        $taskPath = New-LearningTask -Source $nextSource
        Write-Host "[SEMILLA-CLEAN] Created task: $taskPath"
    } else {
        $taskPath = $pendingTasks[0].FullName
        Write-Host "[SEMILLA-CLEAN] Using existing task: $taskPath"
    }

    $response = Invoke-Qwen -TaskPath $taskPath

    $taskFile = Get-Item -LiteralPath $taskPath
    $outName = $taskFile.Name -replace "\.learning_task\.md$", ".qwen_response.md"

    $outPath = Join-Path $OutboxDir $outName
    $processedPath = Join-Path $ProcessedDir $taskFile.Name

    $ResponseText = @"
# Qwen Semilla response · $($taskFile.BaseName)

Created at: $((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))

---

$response
"@

    $ResponseText | Set-Content -LiteralPath $outPath -Encoding UTF8

    Move-Item -LiteralPath $taskPath -Destination $processedPath -Force

    Write-State -Status "OK" -Message "Task processed successfully." -Extra @{
        task = $processedPath
        outbox = $outPath
        model = $Model
    }

    if ($Commit) {
        Commit-Safe -Message "chore: semilla clean learning cycle $(Get-Stamp)" | Out-Null
    }

    return "OK"
}

$result = Run-CleanCycle

if ($result -eq "IDLE_DONE") {
    exit 0
}

if ($result -eq "OK") {
    exit 0
}

throw "Unexpected result: $result"
