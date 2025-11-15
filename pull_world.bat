@echo off
set GIT="C:\Program Files\Git\bin\git.exe"

echo Updating world from GitHub...
%GIT% pull --rebase

echo Update complete.
pause