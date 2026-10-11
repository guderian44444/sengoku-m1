@echo off
chcp 65001 >nul
cd /d "%~dp0"
start "吞食戰國 v0.17 雙人合作" "%~dp0tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%~dp0game" -- --local-coop
