@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Subnautica2MorePlayers8 Direct Connect Client

pushd "%~dp0" >nul 2>&1
if errorlevel 1 (
  echo Failed to enter script directory: "%~dp0"
  pause
  exit /b 1
)

echo Subnautica2MorePlayers8 direct-connect client
echo.

if "%~1"=="" goto prompt_address

set "FIRST_ARG=%~1"
if "%FIRST_ARG:~0,1%"=="-" goto pass_through

powershell -NoProfile -ExecutionPolicy Bypass -File "%CD%\tools\Join-ExperimentalServer.ps1" -Address "%~1" -Windowed
set "RC=%ERRORLEVEL%"
goto done

:pass_through
powershell -NoProfile -ExecutionPolicy Bypass -File "%CD%\tools\Join-ExperimentalServer.ps1" %*
set "RC=%ERRORLEVEL%"
goto done

:prompt_address
set "MP8_ADDRESS="
set /p "MP8_ADDRESS=Enter host IP or hostname: "
if "%MP8_ADDRESS%"=="" (
  echo Address is empty.
  set "RC=1"
  goto done
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%CD%\tools\Join-ExperimentalServer.ps1" -Address "%MP8_ADDRESS%" -Windowed
set "RC=%ERRORLEVEL%"

:done
popd
if not "%RC%"=="0" (
  echo.
  echo Join-ExperimentalServer failed with exit code %RC%.
  pause
)
exit /b %RC%
