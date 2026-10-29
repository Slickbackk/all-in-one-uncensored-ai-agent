[CmdletBinding()]
param([switch]$WebChat, [switch]$CheckOnly, [string]$QueryFile = '')
$ErrorActionPreference = 'Stop'
$process = $null
try {
    $settingsPath = Join-Path $PSScriptRoot 'data\settings.json'
    if (-not (Test-Path -LiteralPath $settingsPath)) { throw 'Run Setup-Ares.cmd first.' }
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    foreach ($path in @($settings.server, $settings.model)) { if (-not (Test-Path -LiteralPath $path)) { throw "Missing: $path. Rerun Setup if you moved the folder." } }
    if (-not $WebChat -and -not $CheckOnly -and -not (Test-Path -LiteralPath $settings.hermes)) { throw 'Hermes is missing. Run full Setup-Ares.cmd.' }
    $port = [int]$settings.port
    $context = [int]$settings.context
    if ($port -lt 1024 -or $port -gt 65535 -or $context -lt 8192 -or $context -gt 32768) { throw 'Invalid port/context in data/settings.json (context must be 8192 to 32768).' }
    if ($settings.model -match '"') { throw 'Invalid model filename.' }
    $devices = & $settings.server --list-devices 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $devices -notmatch 'Vulkan\d') { throw "No Vulkan GPU detected. Update your GPU driver. Details: $devices" }
    if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) { throw "Port $port is occupied. Close the other server or select a different port in data/settings.json." }
    $logs = Join-Path $PSScriptRoot 'data\logs'
    New-Item -ItemType Directory -Force -Path $logs | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $stderr = Join-Path $logs "$stamp.stderr.log"
    $arguments = '-m "{0}" --alias ares --host 127.0.0.1 --port {1} -ngl 999 -c {2} -np 1 -fa on --jinja --cors-origins http://127.0.0.1:{1},http://localhost:{1} -lv 4' -f $settings.model, $port, $context
    Write-Host 'Loading Ares on your GPU...'
    $process = Start-Process -FilePath $settings.server -ArgumentList $arguments -WorkingDirectory (Split-Path $settings.server) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logs "$stamp.stdout.log") -RedirectStandardError $stderr
    $ready = $false
    $deadline = (Get-Date).AddMinutes(5)
    do {
        if ($process.HasExited) { throw "Model server exited. Read $stderr" }
        try {
            $health = Invoke-RestMethod -Uri "http://127.0.0.1:$port/health" -TimeoutSec 2
            $ready = $health.status -eq 'ok'
        } catch { $ready = $false }
        if (-not $ready) { Start-Sleep -Seconds 2 }
    } while (-not $ready -and (Get-Date) -lt $deadline)
    if (-not $ready) { throw "Model loading timed out. Read $stderr" }
    if ($CheckOnly) {
        $body = @{model='ares';messages=@(@{role='user';content='Reply with the word READY.'});max_tokens=32;temperature=0;chat_template_kwargs=@{enable_thinking=$false}} | ConvertTo-Json -Depth 6
        $reply = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$port/v1/chat/completions" -ContentType 'application/json' -Body $body -TimeoutSec 180
        if (-not $reply.choices[0].message.content) { throw 'Model returned no text.' }
        Write-Host "Inference check: $($reply.choices[0].message.content)"
    } elseif ($WebChat) {
        Start-Process "http://127.0.0.1:$port"
        Read-Host 'Local browser chat is running. Press Enter to stop'
    } else {
        $env:HERMES_HOME = $settings.hermes_home
        $configPath = Join-Path $settings.hermes_home 'config.yaml'
        # Keep the endpoint and context synchronized with editable launch settings.
        $config = Get-Content -LiteralPath $configPath -Raw
        $config = $config -replace 'http://127\.0\.0\.1:\d+/v1', "http://127.0.0.1:$port/v1"
        $config = $config -replace '(?m)^(\s*context_length:)\s*\d+', "`$1 $context"
        Set-Content -LiteralPath $configPath -Value $config -Encoding UTF8
        if ($QueryFile) { $QueryFile = (Resolve-Path -LiteralPath $QueryFile).Path }
        Push-Location (Join-Path $PSScriptRoot 'workspace')
        try {
            if ($QueryFile) { & $settings.hermes chat -t terminal,file --query-file $QueryFile --oneshot }
            else { & $settings.hermes chat -t terminal,file }
            if ($LASTEXITCODE -ne 0) { throw "Hermes exited with code $LASTEXITCODE. Model logs: $stderr" }
        } finally { Pop-Location }
    }
} catch { Write-Error $_; exit 1 }
finally {
    # Only the server created by this invocation is stopped.
    if ($null -ne $process -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
}
