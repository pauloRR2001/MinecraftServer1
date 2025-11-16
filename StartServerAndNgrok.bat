@echo off
title Minecraft Server + ngrok Launcher
echo Starting Minecraft server...
start "" cmd /c "LaunchServer.bat"

echo Starting ngrok tunnel on port 25565...
start "" cmd /c "ngrok.exe tcp 25565"

echo Both server and ngrok are running.
echo Your ngrok public address will appear in the ngrok window.
pause