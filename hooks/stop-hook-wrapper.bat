@echo off
REM Ralph Wiggum Stop Hook - Pure Windows wrapper
REM This script works in pure Windows PowerShell environment (no Git Bash required)

setlocal enabledelayedexpansion

REM Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"
set "PLUGIN_ROOT=%SCRIPT_DIR%.."
set "PS_SCRIPT=%PLUGIN_ROOT%\hooks\stop-hook.ps1"

REM Call PowerShell script, passing all input through stdin
REM Using -Command with - to allow stdin input
powershell -NoProfile -ExecutionPolicy Bypass -Command - 2>nul <nul
if errorlevel 1 (
    REM Fallback: try using -File if -Command doesn't work
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
    exit /b !ERRORLEVEL!
)

REM End of script
exit /b 0
