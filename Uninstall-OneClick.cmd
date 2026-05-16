@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-OneClick.ps1"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
  echo Uninstall finished.
) else (
  echo Uninstall failed with exit code %RC%.
)
echo Press any key to close.
pause >nul
exit /b %RC%
