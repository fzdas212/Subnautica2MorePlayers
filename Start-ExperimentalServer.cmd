@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Start-ExperimentalServer.ps1" %*
if errorlevel 1 (
  echo.
  echo Start-ExperimentalServer failed with exit code %errorlevel%.
  pause
)
