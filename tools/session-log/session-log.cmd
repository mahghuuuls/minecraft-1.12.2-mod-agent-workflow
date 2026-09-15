@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0session-log.ps1" %*
exit /b %errorlevel%
