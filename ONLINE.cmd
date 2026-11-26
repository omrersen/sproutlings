@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start_online.ps1"
if errorlevel 1 (echo Sunucu baslatilamadi. & pause & exit /b 1)
start "" "http://127.0.0.1:8769/"
