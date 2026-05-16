@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Collect-MorePlayers8Logs.ps1"
echo.
echo Press any key to close.
pause >nul
