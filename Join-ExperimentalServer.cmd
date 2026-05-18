@echo off
setlocal
title Subnautica2MorePlayers8 Direct Connect Client
echo Subnautica2MorePlayers8 direct-connect client
echo.
if "%~1"=="" (
  set /p MP8_ADDRESS=Enter host IP or hostname:
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Join-ExperimentalServer.ps1" -Address "%MP8_ADDRESS%" -Windowed
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Join-ExperimentalServer.ps1" %*
)
if errorlevel 1 (
  echo.
  echo Join-ExperimentalServer failed with exit code %errorlevel%.
  pause
)
