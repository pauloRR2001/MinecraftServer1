@echo off
setlocal

set "SCRIPT=%~dp0ServerGUI.ps1"

if not exist "%SCRIPT%" (
  echo ServerGUI.ps1 not found at "%SCRIPT%"
  pause
  exit /b 1
)

rem Prefer Windows PowerShell if available, else fall back to powershell/pwsh on PATH
set "PSH=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%PSH%" (
  start "" "%PSH%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
) else (
  start "" powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" || start "" pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
)

endlocal
