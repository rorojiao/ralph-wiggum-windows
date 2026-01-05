# Ralph Wiggum Stop Hook - Inline version
# All logic in one file for easier hook execution

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RALPH_STATE_FILE = ".claude\ralph-loop.local.md"

if (-not (Test-Path $RALPH_STATE_FILE)) {
    exit 0
}

$STATE_CONTENT = Get-Content $RALPH_STATE_FILE -Raw

$frontmatterPattern = '(?s)^---\s*\n(.+?)\n---\s*\n(.*)$'
if ($STATE_CONTENT -match $frontmatterPattern) {
    $FRONTMATTER = $matches[1]
    $PROMPT_TEXT = $matches[2].Trim()
} else {
    $frontmatterPattern = '(?s)^---\r?\n(.+?)\r?\n---\r?\n(.*)$'
    if ($STATE_CONTENT -match $frontmatterPattern) {
        $FRONTMATTER = $matches[1]
        $PROMPT_TEXT = $matches[2].Trim()
    } else {
        Remove-Item $RALPH_STATE_FILE -Force
        exit 0
    }
}

$ITERATION = 0
$MAX_ITERATIONS = 0
$COMPLETION_PROMISE = "null"

if ($FRONTMATTER -match 'iteration:\s*(\d+)') { $ITERATION = [int]$matches[1] }
if ($FRONTMATTER -match 'max_iterations:\s*(\d+)') { $MAX_ITERATIONS = [int]$matches[1] }
if ($FRONTMATTER -match 'completion_promise:\s*"?([^"\r\n]+)"?') {
    $COMPLETION_PROMISE = $matches[1].Trim('"').Trim("'")
}

if ($MAX_ITERATIONS -gt 0 -and $ITERATION -ge $MAX_ITERATIONS) {
    Write-Host "Ralph loop: Max iterations ($MAX_ITERATIONS) reached."
    Remove-Item $RALPH_STATE_FILE -Force
    exit 0
}

$NEXT_ITERATION = $ITERATION + 1
$NEW_FRONTMATTER = $FRONTMATTER -replace 'iteration:\s*\d+', "iteration: $NEXT_ITERATION"
$NEW_STATE = "---`n$NEW_FRONTMATTER`n---`n`n$PROMPT_TEXT"
$TEMP_FILE = "$RALPH_STATE_FILE.tmp.$PID"
Set-Content -Path $TEMP_FILE -Value $NEW_STATE -NoNewline
Move-Item -Path $TEMP_FILE -Destination $RALPH_STATE_FILE -Force

if ($COMPLETION_PROMISE -ne "null" -and -not [string]::IsNullOrEmpty($COMPLETION_PROMISE)) {
    $SYSTEM_MSG = "Ralph iteration $NEXT_ITERATION | To stop: output <promise>$COMPLETION_PROMISE</promise> (ONLY when TRUE)"
} else {
    $SYSTEM_MSG = "Ralph iteration $NEXT_ITERATION | No completion promise set - loop runs infinitely"
}

$output = [PSCustomObject]@{
    decision = "block"
    reason = $PROMPT_TEXT
    systemMessage = $SYSTEM_MSG
}
Write-Output ($output | ConvertTo-Json -Compress)

exit 0
