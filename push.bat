@echo off
setlocal

:: Get the commit message from the first argument, or default to "auto update"
set "COMMIT_MSG=%~1"
if "%COMMIT_MSG%"=="" set "COMMIT_MSG=feat: auto commit from push.bat"

:: Use the exact PowerShell environment path fix and git commands you provided
powershell -NoProfile -Command "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); git add -A; git commit -m '%COMMIT_MSG%'; git push"

echo.
echo [DONE] Code pushed successfully.
pause
