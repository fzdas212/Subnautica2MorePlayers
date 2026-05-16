@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-OneClick.ps1"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
  echo Install finished.
) else (
  echo Install failed with exit code %RC%.
)
echo Press any key to close.
pause >nul
exit /b %RC%
