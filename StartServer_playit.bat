@echo off
title Minecraft Server + playit.gg Tunnel

echo Updating world...
call pull_world.bat

echo.
echo Starting Minecraft server...
start "" cmd /c "LaunchServer.bat"

echo.
echo Starting playit.gg tunnel...
start "" cmd /c "playit.exe"

echo.
echo Your public server address is shown in the playit.gg window.
echo Server and Tunnel are now running.
pause