@echo off
setlocal
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0instance-reset.ps1" %*
exit /b %errorlevel%
