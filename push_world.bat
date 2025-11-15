@echo off
set GIT="C:\Program Files\Git\bin\git.exe"

echo Saving and uploading world...
%GIT% add .
%GIT% commit -m "World update" >NUL 2>&1
%GIT% push

echo Upload complete.
pause