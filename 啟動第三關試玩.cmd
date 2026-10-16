@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\play-stage03-alarm.ps1"
if errorlevel 1 pause
