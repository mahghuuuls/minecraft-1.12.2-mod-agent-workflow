@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0mod-jar.ps1" %*
exit /b %errorlevel%
