@echo off
REM Ralph Wiggum Stop Hook - Windows wrapper
REM Calls PowerShell script on Windows

setlocal

set "PLUGIN_ROOT=%~dp0.."
set "SCRIPT=%PLUGIN_ROOT%\hooks\stop-hook.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%SCRIPT%'"
exit /b %ERRORLEVEL%
