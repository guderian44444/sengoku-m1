param([switch]$StageOnly)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$python = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $python) {
    $python = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
}
if (-not (Test-Path -LiteralPath $python)) { throw 'Python 3 is required to build the package.' }
$arguments = @('-X','utf8',(Join-Path $root 'scripts/package-current.py'))
if ($StageOnly) { $arguments += '--stage-only' }
& $python @arguments
if ($LASTEXITCODE -ne 0) { throw 'Current runtime packaging failed.' }
