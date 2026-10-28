@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0devtool-inbox.ps1" %*
exit /b %errorlevel%
