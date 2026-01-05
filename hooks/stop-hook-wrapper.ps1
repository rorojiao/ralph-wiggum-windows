# Ralph Wiggum Stop Hook - Pure Windows PowerShell wrapper
# This script works in pure Windows PowerShell environment (no Git Bash required)

# Enable strict error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get paths
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PluginRoot = Split-Path -Parent $ScriptRoot
$StopHookScript = Join-Path $PluginRoot "hooks\stop-hook.ps1"

# Check if the main script exists
if (-not (Test-Path $StopHookScript)) {
    Write-Error "Stop hook script not found: $StopHookScript"
    exit 0
}

# Execute the main stop hook script
# Dot-source to run in the same scope
. $StopHookScript
