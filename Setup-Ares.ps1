[CmdletBinding()]
param([string]$ModelPath = '', [switch]$SkipHermes)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = $PSScriptRoot
$runtime = Join-Path $root 'runtime'
$data = Join-Path $root 'data'
$hermesCommit = 'f8489405600c9a7d9d2f307dace086f18d7173ba'
$modelSha = '5b24ea3eebc3e0bccd05fb474eb88b10c57699d71a5db2f29485e3789a70d55d'
function Download-Verified([string]$Url, [string]$Path, [string]$Sha256) {
    if ((Test-Path -LiteralPath $Path) -and (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -eq $Sha256) { return }
    $partial = "$Path.partial"
    Write-Host "Downloading $Url"
    & curl.exe --fail --location --retry 3 --continue-at - --output $partial $Url
    if ($LASTEXITCODE -ne 0) { throw "Download failed. Run Setup again to resume: $partial" }
    if ((Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash -ne $Sha256) {
        throw "Checksum mismatch: $partial. Rename this partial file and rerun Setup to download a fresh copy."
    }
    Move-Item -LiteralPath $partial -Destination $Path -Force
}
try {
    if (-not [Environment]::Is64BitProcess -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') { throw 'Use 64-bit Windows on an x64 CPU.' }
    foreach ($folder in @($runtime, $data, (Join-Path $root 'models'), (Join-Path $root 'workspace'))) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    $zip = Join-Path $runtime 'prism-vulkan.zip'
    Download-Verified 'https://github.com/PrismML-Eng/llama.cpp/releases/download/prism-b10826-c9c34bc/llama-prism-b10826-c9c34bc-bin-win-vulkan-x64.zip' $zip 'f4d923da4c502837f94f0d6a438cf5e862df25ddc29c97ba6b200e9ef6bc16f0'
    $engine = Join-Path $runtime 'engine'
    Expand-Archive -LiteralPath $zip -DestinationPath $engine -Force
    $server = @(Get-ChildItem -LiteralPath $engine -Filter llama-server.exe -Recurse)
    if ($server.Count -ne 1) { throw 'Could not locate exactly one llama-server.exe in the engine archive.' }
    $model = Join-Path $root 'models\Bonsai-2-27B-PQ2_0-CRACK.gguf'
    if ($ModelPath) {
        $model = (Resolve-Path -LiteralPath $ModelPath).Path
        Write-Host 'Verifying your existing model...'
        if ((Get-FileHash -LiteralPath $model -Algorithm SHA256).Hash -ne $modelSha) { throw 'The supplied file is not the supported Bonsai CRACK model.' }
    } else {
        Download-Verified 'https://huggingface.co/dealignai/Bonsai-2-27B-Ternary-CRACK-GGUF/resolve/3d36486a5fb2a3868116b8f6e768179e2391d28d/Bonsai-2-27B-PQ2_0-CRACK.gguf' $model $modelSha
    }
    $homeDir = Join-Path $data 'hermes'
    New-Item -ItemType Directory -Path $homeDir -Force | Out-Null
    $hermes = Join-Path $homeDir 'bin\hermes.exe'
    if (-not $SkipHermes -and -not (Test-Path -LiteralPath $hermes)) {
        $installer = Join-Path $runtime 'install-hermes.ps1'
        Download-Verified "https://raw.githubusercontent.com/NousResearch/hermes-agent/$hermesCommit/scripts/install.ps1" $installer 'a6b97ff8c07260ae2e21f8087cf07d8c733189a639e82d6311ef31eec4c93286'
        # Run upstream setup in a child process: its exit cannot close this script.
        # Git for Windows otherwise rejects long documentation paths in nested folders.
        # Process-scoped configuration reaches the installer's bundled Git too.
        $savedGitCount = $env:GIT_CONFIG_COUNT
        $gitIndex = 0
        if ($savedGitCount) { $gitIndex = [int]$savedGitCount }
        $gitKeyName = "GIT_CONFIG_KEY_$gitIndex"
        $gitValueName = "GIT_CONFIG_VALUE_$gitIndex"
        $savedGitKey = [Environment]::GetEnvironmentVariable($gitKeyName, 'Process')
        $savedGitValue = [Environment]::GetEnvironmentVariable($gitValueName, 'Process')
        try {
            $env:GIT_CONFIG_COUNT = [string]($gitIndex + 1)
            [Environment]::SetEnvironmentVariable($gitKeyName, 'core.longpaths', 'Process')
            [Environment]::SetEnvironmentVariable($gitValueName, 'true', 'Process')
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -Commit $hermesCommit -HermesHome $homeDir -InstallDir (Join-Path $runtime 'hermes-agent') -NonInteractive -SkipBrowser -SkipComputerUse
            $installExit = $LASTEXITCODE
        } finally {
            $env:GIT_CONFIG_COUNT = $savedGitCount
            [Environment]::SetEnvironmentVariable($gitKeyName, $savedGitKey, 'Process')
            [Environment]::SetEnvironmentVariable($gitValueName, $savedGitValue, 'Process')
        }
        if ($installExit -ne 0) { throw 'Hermes dependency installation failed. See the installer output; rerun Setup after resolving the error.' }
    }
    if (-not $SkipHermes -and -not (Test-Path -LiteralPath $hermes)) { throw 'Hermes launcher was not created.' }
    if (-not $SkipHermes) {
        # The pinned Hermes version rejects contexts under 64K. Ares uses a
        # reduced toolset and 16K context for consumer GPUs. Patch only this
        # private installation; never alter a pre-existing Hermes installation.
        $metadataPath = Join-Path $runtime 'hermes-agent\agent\model_metadata.py'
        $metadata = [IO.File]::ReadAllText($metadataPath)
        if ($metadata.Contains('MINIMUM_CONTEXT_LENGTH = 64_000')) {
            $metadata = $metadata.Replace('MINIMUM_CONTEXT_LENGTH = 64_000', 'MINIMUM_CONTEXT_LENGTH = 8_192  # Ares small-context compatibility')
            [IO.File]::WriteAllText($metadataPath, $metadata, (New-Object Text.UTF8Encoding($false)))
        } elseif (-not $metadata.Contains('MINIMUM_CONTEXT_LENGTH = 8_192  # Ares small-context compatibility')) {
            throw 'Hermes context guard changed. This Ares compatibility patch must be reviewed before setup can continue.'
        }
    }
    $config = Join-Path $homeDir 'config.yaml'
    if (Test-Path -LiteralPath $config) { Copy-Item -LiteralPath $config -Destination "$config.before-ares" -Force }
    Copy-Item -LiteralPath (Join-Path $root 'config.example.yaml') -Destination $config -Force
    Copy-Item -LiteralPath (Join-Path $root 'SOUL.md') -Destination (Join-Path $homeDir 'SOUL.md') -Force
    @{ server = $server[0].FullName; model = $model; hermes = $hermes; hermes_home = $homeDir; port = 18081; context = 16384 } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $data 'settings.json') -Encoding UTF8
    if ($SkipHermes) { Write-Host 'Engine setup complete. Hermes was skipped; run full Setup before starting the agent.' }
    else { Write-Host 'Ares is ready. Double-click Start-Ares.cmd.' -ForegroundColor Green }
} catch { Write-Error $_; exit 1 }
