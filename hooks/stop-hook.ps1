# Ralph Wiggum Stop Hook (PowerShell version)
# Prevents session exit when a ralph-loop is active
# Feeds Claude's output back as input to continue the loop

# Enable strict error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Read hook input from stdin (advanced stop hook API)
# Try multiple methods for maximum compatibility
$HOOK_INPUT = ""
if ($null -ne $input) {
    # Input from pipeline
    $HOOK_INPUT = $input | Out-String
} else {
    # Try console stdin
    $HOOK_INPUT = [Console]::In.ReadToEnd()
}

# If still empty, try environment variable (for .bat compatibility)
if ([string]::IsNullOrEmpty($HOOK_INPUT) -and $env:RALPH_HOOK_INPUT) {
    $HOOK_INPUT = $env:RALPH_HOOK_INPUT
}

# Check if ralph-loop is active
$RALPH_STATE_FILE = ".claude\ralph-loop.local.md"

if (-not (Test-Path $RALPH_STATE_FILE)) {
    # No active loop - allow exit
    exit 0
}

# Read the entire state file
$STATE_CONTENT = Get-Content $RALPH_STATE_FILE -Raw

# Parse YAML frontmatter (content between --- markers)
# Use single-line option for regex to handle multiline
$frontmatterPattern = '(?s)^---\s*\n(.+?)\n---\s*\n(.*)$'
if ($STATE_CONTENT -match $frontmatterPattern) {
    $FRONTMATTER = $matches[1]
    $PROMPT_TEXT = $matches[2].Trim()
} else {
    # Try alternative pattern (Windows line endings)
    $frontmatterPattern = '(?s)^---\r?\n(.+?)\r?\n---\r?\n(.*)$'
    if ($STATE_CONTENT -match $frontmatterPattern) {
        $FRONTMATTER = $matches[1]
        $PROMPT_TEXT = $matches[2].Trim()
    } else {
        # Corrupted state file
        [Console]::Error.WriteLine("Ralph loop: State file corrupted or incomplete. No valid frontmatter found.")
        Remove-Item $RALPH_STATE_FILE -Force
        exit 0
    }
}

# Parse frontmatter values
$ITERATION = 0
$MAX_ITERATIONS = 0
$COMPLETION_PROMISE = "null"

if ($FRONTMATTER -match 'iteration:\s*(\d+)') {
    $ITERATION = [int]$matches[1]
}

if ($FRONTMATTER -match 'max_iterations:\s*(\d+)') {
    $MAX_ITERATIONS = [int]$matches[1]
}

if ($FRONTMATTER -match 'completion_promise:\s*"?([^"\r\n]+)"?') {
    $COMPLETION_PROMISE = $matches[1]
    # Remove trailing quotes if present
    $COMPLETION_PROMISE = $COMPLETION_PROMISE.Trim('"').Trim("'")
}

# Validate numeric fields
if ($ITERATION -lt 0) {
    [Console]::Error.WriteLine("Ralph loop: State file corrupted. 'iteration' field is not a valid number.")
    Remove-Item $RALPH_STATE_FILE -Force
    exit 0
}

if ($MAX_ITERATIONS -lt 0) {
    [Console]::Error.WriteLine("Ralph loop: State file corrupted. 'max_iterations' field is not a valid number.")
    Remove-Item $RALPH_STATE_FILE -Force
    exit 0
}

# Check if max iterations reached
if ($MAX_ITERATIONS -gt 0 -and $ITERATION -ge $MAX_ITERATIONS) {
    [Console]::WriteLine("Ralph loop: Max iterations ($MAX_ITERATIONS) reached.")
    Remove-Item $RALPH_STATE_FILE -Force
    exit 0
}

# Parse hook input JSON to get transcript path
try {
    $HOOK_JSON = $HOOK_INPUT | ConvertFrom-Json
    $TRANSCRIPT_PATH = $HOOK_JSON.transcript_path
} catch {
    # Failed to parse hook input - allow exit
    exit 0
}

if (-not (Test-Path $TRANSCRIPT_PATH)) {
    [Console]::Error.WriteLine("Ralph loop: Transcript file not found at: $TRANSCRIPT_PATH")
    Remove-Item $RALPH_STATE_FILE -Force
    exit 0
}

# Read transcript lines (JSONL format)
$TRANSCRIPT_LINES = Get-Content $TRANSCRIPT_PATH

# Find last assistant message
$LAST_ASSISTANT_LINE = $null
foreach ($line in $TRANSCRIPT_LINES) {
    if ($line -match '"role"\s*:\s*"assistant"') {
        $LAST_ASSISTANT_LINE = $line
    }
}

if (-not $LAST_ASSISTANT_LINE) {
    [Console]::Error.WriteLine("Ralph loop: No assistant messages found in transcript.")
    Remove-Item $RALPH_STATE_FILE -Force
    exit 0
}

# Parse JSON and extract text content
try {
    $MSG_JSON = $LAST_ASSISTANT_LINE | ConvertFrom-Json
    $LAST_OUTPUT = ""

    # Extract text from message.content array
    if ($MSG_JSON.message.content) {
        foreach ($item in $MSG_JSON.message.content) {
            if ($item.type -eq "text" -and $item.text) {
                $LAST_OUTPUT += $item.text + "`n"
            }
        }
    }
    $LAST_OUTPUT = $LAST_OUTPUT.Trim()
} catch {
    [Console]::Error.WriteLine("Ralph loop: Failed to parse assistant message JSON.")
    Remove-Item $RALPH_STATE_FILE -Force
    exit 0
}

if ([string]::IsNullOrWhiteSpace($LAST_OUTPUT)) {
    [Console]::Error.WriteLine("Ralph loop: Assistant message contained no text content.")
    Remove-Item $RALPH_STATE_FILE -Force
    exit 0
}

# Check for completion promise (only if set and not null)
if ($COMPLETION_PROMISE -ne "null" -and -not [string]::IsNullOrEmpty($COMPLETION_PROMISE)) {
    # Extract text from <promise> tags using regex (non-greedy, multiline)
    $promisePattern = '(?s)<promise>\s*(.+?)\s*</promise>'
    if ($LAST_OUTPUT -match $promisePattern) {
        $PROMISE_TEXT = $matches[1].Trim()

        # Normalize whitespace for comparison
        $PROMISE_TEXT = $PROMISE_TEXT -replace '\s+', ' '
        $COMPLETION_PROMISE_NORM = $COMPLETION_PROMISE -replace '\s+', ' '

        if ($PROMISE_TEXT -eq $COMPLETION_PROMISE_NORM) {
            [Console]::WriteLine("Ralph loop: Detected <promise>$COMPLETION_PROMISE</promise>")
            Remove-Item $RALPH_STATE_FILE -Force
            exit 0
        }
    }
}

# Not complete - continue loop with SAME PROMPT
$NEXT_ITERATION = $ITERATION + 1

# Check if prompt text is empty
if ([string]::IsNullOrWhiteSpace($PROMPT_TEXT)) {
    [Console]::Error.WriteLine("Ralph loop: State file corrupted or incomplete. No prompt text found.")
    Remove-Item $RALPH_STATE_FILE -Force
    exit 0
}

# Update iteration in frontmatter
$NEW_FRONTMATTER = $FRONTMATTER -replace 'iteration:\s*\d+', "iteration: $NEXT_ITERATION"
$NEW_STATE = "---`n$NEW_FRONTMATTER`n---`n`n$PROMPT_TEXT"

# Atomic file update: write to temp file then move
$TEMP_FILE = "$RALPH_STATE_FILE.tmp.$PID"
Set-Content -Path $TEMP_FILE -Value $NEW_STATE -NoNewline
Move-Item -Path $TEMP_FILE -Destination $RALPH_STATE_FILE -Force

# Build system message
if ($COMPLETION_PROMISE -ne "null" -and -not [string]::IsNullOrEmpty($COMPLETION_PROMISE)) {
    $SYSTEM_MSG = "Ralph iteration $NEXT_ITERATION | To stop: output <promise>$COMPLETION_PROMISE</promise> (ONLY when statement is TRUE - do not lie to exit!)"
} else {
    $SYSTEM_MSG = "Ralph iteration $NEXT_ITERATION | No completion promise set - loop runs infinitely"
}

# Create output object and convert to JSON (handles escaping properly)
$output = [PSCustomObject]@{
    decision = "block"
    reason = $PROMPT_TEXT
    systemMessage = $SYSTEM_MSG
}

# Convert to JSON and output (Compress for single line)
$OUTPUT_JSON = $output | ConvertTo-Json -Compress

# Write to stdout without newline
[Console]::Write($OUTPUT_JSON)

exit 0
