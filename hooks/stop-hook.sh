#!/bin/bash
# Ralph Wiggum Stop Hook - Wrapper that calls PowerShell
# This works in bash/Git Bash environments by delegating to PowerShell

# Get the plugin root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Convert to Windows path format
PS_SCRIPT="$(echo "$PLUGIN_ROOT/hooks/stop-hook.ps1" | sed 's|/|\\|g')"

# Call PowerShell
# Use powershell.exe which works on Windows
# Pass input through stdin
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT" 2>/dev/null

# Exit with the same code
exit $?
