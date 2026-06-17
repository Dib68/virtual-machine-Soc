@echo off
title CyberSec AI VM - Installer
REM Auto-elevazione a amministratore (serve per installare VirtualBox/Vagrant)
net session >nul 2>&1
if %errorLevel% neq 0 (
  echo Richiedo i permessi di amministratore...
  powershell -Command "Start-Process '%~f0' -Verb RunAs"
  exit /b
)
echo.
echo  Avvio installazione automatica della CyberSec AI VM...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\bootstrap.ps1"
echo.
pause
