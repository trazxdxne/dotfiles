@echo off
setlocal
set "PATCHER_DIR="

if exist "C:\WINDOWS\system32\eligibility-antigravity-patcher\manager.py" (
    set "PATCHER_DIR=C:\WINDOWS\system32\eligibility-antigravity-patcher"
) else if exist "%USERPROFILE%\.local\share\eligibility-antigravity-patcher\manager.py" (
    set "PATCHER_DIR=%USERPROFILE%\.local\share\eligibility-antigravity-patcher"
) else if exist "%USERPROFILE%\eligibility-antigravity-patcher\manager.py" (
    set "PATCHER_DIR=%USERPROFILE%\eligibility-antigravity-patcher"
) else (
    echo :: Cloning eligibility-antigravity-patcher...
    mkdir "%USERPROFILE%\.local\share" 2>nul
    git clone https://github.com/QNIX-Dev/eligibility-antigravity-patcher "%USERPROFILE%\.local\share\eligibility-antigravity-patcher"
    set "PATCHER_DIR=%USERPROFILE%\.local\share\eligibility-antigravity-patcher"
)

if "%~1"=="" (
    python "%PATCHER_DIR%\manager.py" patch
) else (
    python "%PATCHER_DIR%\manager.py" %*
)
