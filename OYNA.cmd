@echo off
setlocal
cd /d "%~dp0"
for %%G in ("%LOCALAPPDATA%\SproutlingsEngine\Godot*win64.exe") do (
  if exist "%%~fG" (
    start "" "%%~fG" --path "%~dp0."
    exit /b 0
  )
)
for /r "%LOCALAPPDATA%\Microsoft\WinGet\Packages" %%G in (Godot*win64.exe) do (
  if exist "%%G" (
    start "" "%%G" --path "%~dp0."
    exit /b 0
  )
)
where godot >nul 2>&1
if not errorlevel 1 (
  start "" godot --path "%~dp0."
  exit /b 0
)
echo Godot 4 executable not found.
pause
