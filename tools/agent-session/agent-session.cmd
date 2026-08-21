@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0agent-session.ps1" %*
exit /b %errorlevel%
