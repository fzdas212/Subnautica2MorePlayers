@echo off
setlocal
title Subnautica2MorePlayers8 Graphical Server Console
echo Subnautica2MorePlayers8 graphical server console
echo.
echo This starts the real Subnautica 2 client in a small window and monitors logs.
echo Default mode uses the game's built-in UWESmoketest LAN listen-server path.
echo It is not a headless server; it is a graphical host controlled from this CMD window.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Start-ExperimentalServer.ps1" -Windowed -ServerApiMode OfficialSmokeTestLanListen -Monitor %*
echo.
echo Server console exited with code %errorlevel%.
pause
