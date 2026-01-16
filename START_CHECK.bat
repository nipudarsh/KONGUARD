@echo off
setlocal

REM KONGUARD launcher (minimal, enterprise-safe)
REM Usage:
REM   START_CHECK.bat
REM   START_CHECK.bat tech

cd /d "%~dp0"

set "MODE=%~1"
if "%MODE%"=="" set "MODE=user"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0konguard.ps1" -Mode %MODE%

endlocal

