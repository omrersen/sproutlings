@echo off
setlocal
cd /d "%~dp0"
for %%G in ("%LOCALAPPDATA%\SproutlingsEngine\Godot*win64.exe") do (
  if exist "%%~fG" (
    call :launch "%%~fG"
    exit /b
  )
)
for /r "%LOCALAPPDATA%\Microsoft\WinGet\Packages" %%G in (Godot*win64.exe) do (
  if exist "%%~fG" (
    call :launch "%%~fG"
    exit /b
  )
)
where godot >nul 2>&1
if not errorlevel 1 (
  call :launch godot
  exit /b
)
echo Godot 4 executable not found.
pause
exit /b 1

:launch
if not exist ".godot\sproutlings_assets_v20.ready" (
  echo Importing game assets...
  start "" /wait "%~1" --headless --editor --path "%~dp0." --import
  if errorlevel 1 exit /b 1
  if not exist ".godot\imported" exit /b 1
  type nul > ".godot\sproutlings_assets_v20.ready"
)
start "" "%~1" --path "%~dp0."
exit /b 0