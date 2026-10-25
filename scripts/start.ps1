param([switch]$NoBuild, [switch]$DownloadModels, [int]$Port = 8000)
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot
$runtime = @((Join-Path $projectDir '.venv\Scripts\python.exe'), (Join-Path $projectDir '.tools\python\python.exe')) |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $runtime) { throw 'Create the Python environment using README.md first.' }
if ($Port -lt 1024 -or $Port -gt 65535) { throw 'Use a port from 1024 through 65535.' }
Push-Location -LiteralPath $projectDir
try {
    if ($DownloadModels) {
        & $runtime -m backend.download_models
        if ($LASTEXITCODE -ne 0) { throw 'Model download failed.' }
    }
    if (-not $NoBuild) {
        flutter build web --release
        if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed.' }
    }
    if (-not (Test-Path -LiteralPath 'build/web/index.html')) { throw 'Run without -NoBuild to build the web app first.' }
    Write-Host "Open http://127.0.0.1:$Port and configure that server in the app's Settings. Ctrl+C stops the server."
    & $runtime -m uvicorn backend.app:app --host 127.0.0.1 --port $Port --no-access-log
    if ($LASTEXITCODE -ne 0) { throw 'Inference server exited with an error.' }
} finally { Pop-Location }
