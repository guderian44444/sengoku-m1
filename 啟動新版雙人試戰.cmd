@echo off
chcp 65001 >nul
cd /d "%~dp0"
start "吞食戰國 新版兩人試戰" "tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path game -- --training --drill=enemies
