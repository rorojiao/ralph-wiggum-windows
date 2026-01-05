#!/bin/bash

# Ralph Wiggum Stop Hook Wrapper
# Works in Git Bash environment by calling PowerShell script

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
PS_SCRIPT="$PLUGIN_ROOT/hooks/stop-hook.ps1"

# Convert Windows path to Git Bash format if needed
PS_SCRIPT=$(echo "$PS_SCRIPT" | sed 's|\\|/|g')

# Call PowerShell script with stdin input
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT"
exit $?
