@echo off
setlocal

REM Get the plugin root directory (parent of hooks directory)
set "SCRIPT_DIR=%~dp0"
set "PLUGIN_ROOT=%SCRIPT_DIR%.."

REM Read stdin to a temp file for PowerShell to read
set "TEMP_INPUT=%TEMP%\ralph-hook-input-%RANDOM%.txt"
for /f "delims=" %%i in ('findstr /V "^$"') do set "HOOK_INPUT=%%i"

REM Call PowerShell script with input via environment variable
set "RALPH_HOOK_INPUT=%HOOK_INPUT%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { $env:RALPH_HOOK_INPUT | & '%PLUGIN_ROOT%\hooks\stop-hook.ps1' }"

REM Cleanup
del "%TEMP_INPUT%" 2>nul

exit /b %ERRORLEVEL%
