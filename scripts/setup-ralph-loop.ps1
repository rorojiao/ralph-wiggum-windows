# Ralph Loop Setup Script (PowerShell version)
# Creates state file for in-session Ralph loop

# Enable strict error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Initialize variables
$PROMPT_PARTS = @()
$MAX_ITERATIONS = 0
$COMPLETION_PROMISE = "null"

# Parse arguments using $args automatic variable
$scriptArgs = $args
$i = 0
while ($i -lt $scriptArgs.Count) {
    $arg = $scriptArgs[$i]

    switch ($arg) {
        { $_ -eq "-h" -or $_ -eq "--help" } {
            Write-Host @"
Ralph Loop - Interactive self-referential development loop

USAGE:
  /ralph-loop [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Initial prompt to start the loop (can be multiple words without quotes)

OPTIONS:
  --max-iterations <n>           Maximum iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Custom completion phrase (USE QUOTES for multi-word)
  -h, --help                     Show this help message

DESCRIPTION:
  Starts a Ralph Wiggum loop in your CURRENT session. The stop hook prevents
  exit and feeds your output back as input until completion or iteration limit.

COMPLETION DETECTION:
  - WITHOUT --completion-promise: Auto-detects common phrases like:
    * Chinese: 完成, 已完成, 交付完成, 任务完成, ✅完成
    * English: done, completed, finished, task complete
  - WITH --completion-promise: Only exits when <promise>YOUR_PHRASE</promise> is output

  To manually stop: output <promise>DONE</promise> or <promise>完成</promise>

  Use this for:
  - Interactive iteration where you want to see progress
  - Tasks requiring self-correction and refinement
  - Learning how Ralph works

EXAMPLES:
  /ralph-loop Build a todo API --completion-promise 'DONE' --max-iterations 20
  /ralph-loop --max-iterations 10 Fix the auth bug
  /ralph-loop Refactor cache layer  (auto-stops on completion phrases)
  /ralph-loop --completion-promise 'TASK COMPLETE' Create a REST API

STOPPING:
  - Auto-stop when completion phrases detected (default mode)
  - When --max-iterations reached
  - When --completion-promise phrase is output

MONITORING:
  # View current iteration:
  Get-Content .claude\ralph-loop.local.md | Select-String 'iteration:'

  # View full state:
  Get-Content .claude\ralph-loop.local.md -Head 10
"@
            exit 0
        }
        "--max-iterations" {
            if ($i + 1 -ge $scriptArgs.Count) {
                Write-Error "Error: --max-iterations requires a number argument`n`n   Valid examples:`n     --max-iterations 10`n     --max-iterations 50`n     --max-iterations 0  (unlimited)`n`n   You provided: --max-iterations (with no number)"
                exit 1
            }
            $value = $scriptArgs[$i + 1]
            if ($value -notmatch '^\d+$') {
                Write-Error "Error: --max-iterations must be a positive integer or 0, got: $value`n`n   Valid examples:`n     --max-iterations 10`n     --max-iterations 50`n     --max-iterations 0  (unlimited)`n`n   Invalid: decimals (10.5), negative numbers (-5), text"
                exit 1
            }
            $MAX_ITERATIONS = [int]$value
            $i += 2
        }
        "--completion-promise" {
            if ($i + 1 -ge $scriptArgs.Count) {
                Write-Error "Error: --completion-promise requires a text argument`n`n   Valid examples:`n     --completion-promise 'DONE'`n     --completion-promise 'TASK COMPLETE'`n     --completion-promise 'All tests passing'`n`n   You provided: --completion-promise (with no text)`n`n   Note: Multi-word promises must be quoted!"
                exit 1
            }
            $COMPLETION_PROMISE = $scriptArgs[$i + 1]
            $i += 2
        }
        default {
            # Non-option argument - collect all as prompt parts
            $PROMPT_PARTS += $arg
            $i++
        }
    }
}

# Join all prompt parts with spaces
$PROMPT = $PROMPT_PARTS -join " "

# Validate prompt is non-empty
if ([string]::IsNullOrWhiteSpace($PROMPT)) {
    Write-Error "Error: No prompt provided`n`n   Ralph needs a task description to work on.`n`n   Examples:`n     /ralph-loop Build a REST API for todos`n     /ralph-loop Fix the auth bug --max-iterations 20`n     /ralph-loop --completion-promise 'DONE' Refactor code`n`n   For all options: /ralph-loop --help"
    exit 1
}

# Create state file for stop hook (markdown with YAML frontmatter)
$STATE_DIR = ".claude"
if (-not (Test-Path $STATE_DIR)) {
    New-Item -ItemType Directory -Path $STATE_DIR -Force | Out-Null
}

# Quote completion promise for YAML if needed
if (-not [string]::IsNullOrEmpty($COMPLETION_PROMISE) -and $COMPLETION_PROMISE -ne "null") {
    $COMPLETION_PROMISE_YAML = "`"$COMPLETION_PROMISE`""
} else {
    $COMPLETION_PROMISE_YAML = "null"
}

# Get UTC timestamp
$STARTED_AT = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Create state file content using string formatting
$STATE_CONTENT = @"
---
active: true
iteration: 1
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
started_at: "$STARTED_AT"
---

$PROMPT
"@

# Write state file with UTF-8 encoding (no BOM)
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path (Get-Location) ".claude\ralph-loop.local.md"), $STATE_CONTENT, $Utf8NoBom)

# Build max iterations display
$maxIterDisplay = if ($MAX_ITERATIONS -gt 0) { $MAX_ITERATIONS.ToString() } else { "unlimited" }

# Build completion promise display
$promiseDisplay = if ($COMPLETION_PROMISE -ne "null" -and -not [string]::IsNullOrEmpty($COMPLETION_PROMISE)) {
    "$COMPLETION_PROMISE (ONLY output when TRUE - do not lie!)"
} else {
    "none (runs forever)"
}

# Output setup message
Write-Host @"
Ralph loop activated in this session!

Iteration: 1
Max iterations: $maxIterDisplay
Completion promise: $promiseDisplay

The stop hook is now active. When you try to exit, the SAME PROMPT will be
fed back to you. You'll see your previous work in files, creating a
self-referential loop where you iteratively improve on the same task.

To monitor: Get-Content .claude\ralph-loop.local.md

WARNING: This loop cannot be stopped manually! It will run infinitely
    unless you set --max-iterations or --completion-promise.

"@

# Output the initial prompt
Write-Host $PROMPT
