@echo off
setlocal EnableDelayedExpansion

echo ========================================
echo          Git Auto Push Script
echo ========================================
echo.

:: Get commit message from argument or use default
set "COMMIT_MSG=%~1"
if "%COMMIT_MSG%"=="" (
    set "COMMIT_MSG=feat: auto commit from push.bat"
)

echo Commit message: "%COMMIT_MSG%"
echo.

:: Refresh Git Path safely
powershell -NoProfile -Command "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User');" >nul 2>&1

echo Pulling latest changes (with auto-stash for unstaged files)...
git pull origin master --rebase --autostash

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Pull failed. Please check the errors above.
    echo Common fixes:
    echo   - Run "git status" to see issues
    echo   - Manually commit or stash your changes
    pause
    exit /b 1
)

:: Add all changes
echo Adding changes...
git add -A

:: Commit only if there are actual changes
git diff --cached --quiet
if %errorlevel% equ 0 (
    echo No new changes to commit.
) else (
    echo Committing changes...
    git commit -m "%COMMIT_MSG%"
)

:: Push
echo Pushing to GitHub...
git push origin master

if %errorlevel% equ 0 (
    echo.
    echo [SUCCESS] Code pushed successfully!
) else (
    echo.
    echo [ERROR] Push failed. Check your internet or repository access.
)

echo.
pause