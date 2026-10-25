$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot
$runtime = @((Join-Path $projectDir '.venv\Scripts\python.exe'), (Join-Path $projectDir '.tools\python\python.exe')) |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $runtime) { throw 'Create the Python environment using README.md and install backend/requirements-dev.txt.' }
Push-Location -LiteralPath $projectDir
try {
    flutter analyze --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
    flutter test --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
    & $runtime -m ruff check backend
    if ($LASTEXITCODE -ne 0) { throw 'Python lint failed.' }
    & $runtime -m pytest backend/tests -q
    if ($LASTEXITCODE -ne 0) { throw 'Backend tests failed.' }
} finally { Pop-Location }
