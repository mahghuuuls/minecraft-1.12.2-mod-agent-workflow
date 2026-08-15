@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0evidence-pack.ps1" %*
exit /b %errorlevel%
