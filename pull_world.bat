@echo off
set GIT=portablegit\PortableGit\bin\git.exe

echo Updating world from GitHub...
%GIT% pull --rebase

echo Update complete.
pause