param([switch]$Coop, [ValidateRange(0,3)][int]$StartScene = 0, [string]$GodotBin = "", [string]$ReviewDir = "")
$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
if (-not $GodotBin) { $GodotBin = $env:GODOT_BIN }
if (-not $GodotBin) { $GodotBin = Join-Path $workspace 'tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotBin -PathType Leaf)) { throw 'Set GODOT_BIN or pass -GodotBin pointing to Godot 4.7.2.' }
$sessionData = Join-Path $workspace 'artifacts\stage03-playerdata'
New-Item -ItemType Directory -Path $sessionData -Force | Out-Null
$previousAppData = $env:APPDATA
$previousXdgData = $env:XDG_DATA_HOME
$previousXdgCache = $env:XDG_CACHE_HOME
$previousXdgConfig = $env:XDG_CONFIG_HOME
try {
    $env:APPDATA = $sessionData
    $env:XDG_DATA_HOME = Join-Path $sessionData 'xdg-data'
    $env:XDG_CACHE_HOME = Join-Path $sessionData 'xdg-cache'
    $env:XDG_CONFIG_HOME = Join-Path $sessionData 'xdg-config'
    $arguments = @('--path', (Join-Path $workspace 'game'), '--log-file', (Join-Path $sessionData 'play.log'), '--windowed', '--script', 'res://tests/play_stage03_alarm.gd', '--')
    if ($Coop) { $arguments += '--coop' }
    if ($StartScene -gt 0) { $arguments += "--scene=$StartScene" }
    if ($ReviewDir) { $arguments += "--review-dir=$ReviewDir" }
    & $GodotBin @arguments
    if ($LASTEXITCODE -ne 0) { throw "Godot exited with $LASTEXITCODE; see $sessionData\play.log" }
} finally {
    $env:APPDATA = $previousAppData
    $env:XDG_DATA_HOME = $previousXdgData
    $env:XDG_CACHE_HOME = $previousXdgCache
    $env:XDG_CONFIG_HOME = $previousXdgConfig
}
