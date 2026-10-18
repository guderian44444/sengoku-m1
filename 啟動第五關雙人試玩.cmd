@echo off
setlocal
cd /d "%~dp0"
set "APPDATA=%~dp0artifacts\stage05-playtest\appdata"
if not exist "%APPDATA%" mkdir "%APPDATA%"
"%~dp0tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%~dp0game" --windowed --script res://tests/play_stage05.gd -- --coop %*
endlocal
