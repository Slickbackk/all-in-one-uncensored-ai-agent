@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-Ares.ps1" %*
set "ARES_EXIT=%ERRORLEVEL%"
pause
exit /b %ARES_EXIT%
