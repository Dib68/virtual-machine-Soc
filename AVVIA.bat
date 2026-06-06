@echo off
title CyberSec AI VM - Avvio
cd /d "%~dp0"
echo Accendo la CyberSec AI VM (puo' richiedere un minuto)...
where vagrant >nul 2>&1
if %errorLevel% neq 0 (
  echo Vagrant non trovato. Esegui prima INSTALLA.bat.
  pause
  exit /b
)
vagrant up
echo.
echo VM avviata. Login: vagrant / vagrant
pause
