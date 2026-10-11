@echo off
cd /d "%~dp0"
start "Sengoku Training" "%~dp0tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%~dp0game" -- --training
