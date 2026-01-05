#!/usr/bin/env node

/**
 * Ralph Wiggum Stop Hook - Pure Node.js implementation
 * Works on Windows without bash/WSL
 */

const fs = require('fs');
const path = require('path');

// Default completion phrases when no explicit promise is set
// These are common ways AI indicates task completion
const DEFAULT_COMPLETION_PHRASES = [
    // Chinese phrases
    '完成', '已完成', '交付完成', '任务完成', '功能完成', '代码完成',
    '已实现', '交付', '已完成交付', '✅完成', '✓完成', '✅', '✓',
    // English phrases
    'done', 'complete', 'completed', 'finished', 'task complete',
    'all done', 'ready', 'success', ' accomplished',
    // Short confirmations
    'ok', '好了', '可以了'
];

// Read hook input from stdin
let hookInput = '';

// Use synchronous stdin reading for Windows compatibility
if (process.stdin.isTTY) {
    // No stdin input
    hookInput = '';
} else {
    try {
        hookInput = fs.readFileSync(0, 'utf8');
    } catch (e) {
        hookInput = '';
    }
}

// State file path
const RALPH_STATE_FILE = path.join(process.cwd(), '.claude', 'ralph-loop.local.md');

// Check if ralph-loop is active
if (!fs.existsSync(RALPH_STATE_FILE)) {
    // No active loop - allow exit
    process.exit(0);
}

// Read state file
let stateContent;
try {
    stateContent = fs.readFileSync(RALPH_STATE_FILE, 'utf8');
} catch (e) {
    process.exit(0);
}

// Parse YAML frontmatter
const frontmatterMatch = stateContent.match(/^---\s*\n([\s\S]+?)\n---\s*\n([\s\S]*)$/);
if (!frontmatterMatch) {
    // State file corrupted - silently clean up and allow exit
    try { fs.unlinkSync(RALPH_STATE_FILE); } catch (e) {}
    process.exit(0);
}

const frontmatter = frontmatterMatch[1];
const promptText = frontmatterMatch[2].trim();

// Parse frontmatter values
let iteration = 0;
let maxIterations = 0;
let completionPromise = null;

const iterMatch = frontmatter.match(/iteration:\s*(\d+)/);
if (iterMatch) iteration = parseInt(iterMatch[1], 10);

const maxIterMatch = frontmatter.match(/max_iterations:\s*(\d+)/);
if (maxIterMatch) maxIterations = parseInt(maxIterMatch[1], 10);

// Parse completion_promise - handle both quoted and unquoted values
// First try to match quoted value: completion_promise: "value"
const quotedPromiseMatch = frontmatter.match(/completion_promise:\s*"([^"]*)"/);
if (quotedPromiseMatch) {
    completionPromise = quotedPromiseMatch[1];
} else {
    // Try to match unquoted value: completion_promise: value or completion_promise: null
    const unquotedPromiseMatch = frontmatter.match(/completion_promise:\s*(\S+)/);
    if (unquotedPromiseMatch) {
        const val = unquotedPromiseMatch[1];
        // If it's the literal string "null", set to null, otherwise use the value
        completionPromise = (val === 'null') ? null : val;
    }
}

// Check if max iterations reached
if (maxIterations > 0 && iteration >= maxIterations) {
    // Max iterations reached - allow exit silently
    try { fs.unlinkSync(RALPH_STATE_FILE); } catch (e) {}
    process.exit(0);
}

// Parse hook input to get transcript path
let transcriptPath = null;
if (hookInput) {
    try {
        const hookJson = JSON.parse(hookInput.trim());
        transcriptPath = hookJson.transcript_path;
    } catch (e) {
        // Failed to parse - continue without transcript
    }
}

// Check transcript if available
if (transcriptPath && fs.existsSync(transcriptPath)) {
    try {
        const transcriptLines = fs.readFileSync(transcriptPath, 'utf8').split('\n');
        let lastAssistantLine = null;

        for (const line of transcriptLines) {
            if (line.includes('"role":"assistant"') || line.includes('"role": "assistant"')) {
                lastAssistantLine = line;
            }
        }

        if (lastAssistantLine) {
            const msgJson = JSON.parse(lastAssistantLine);
            let lastOutput = '';

            if (msgJson.message && msgJson.message.content) {
                for (const item of msgJson.message.content) {
                    if (item.type === 'text' && item.text) {
                        lastOutput += item.text + '\n';
                    }
                }
            }

            // Check for completion promise (either explicit or default phrases)
            let shouldExit = false;

            if (completionPromise && completionPromise !== null) {
                // Check for explicit <promise> tag
                const promiseTagMatch = lastOutput.match(/<promise>\s*([\s\S]*?)\s*<\/promise>/);
                if (promiseTagMatch) {
                    const promiseText = promiseTagMatch[1].trim().replace(/\s+/g, ' ');
                    const normalizedPromise = completionPromise.replace(/\s+/g, ' ');

                    if (promiseText === normalizedPromise) {
                        shouldExit = true;
                    }
                }
            } else {
                // No explicit promise set - check for default completion phrases
                const normalizedOutput = lastOutput.toLowerCase().replace(/\s+/g, '').replace(/[✓✅✔]/g, '');

                for (const phrase of DEFAULT_COMPLETION_PHRASES) {
                    const normalizedPhrase = phrase.toLowerCase().replace(/\s+/g, '');
                    // Check if the phrase appears as a standalone indicator
                    if (normalizedOutput.includes(normalizedPhrase)) {
                        // Additional check: make sure it's not part of a larger word
                        // by looking for word boundaries or line boundaries
                        const outputWords = normalizedOutput.split(/[,。，！!？?\n\r]+/);
                        for (const word of outputWords) {
                            if (word === normalizedPhrase || word.startsWith(normalizedPhrase) || word.endsWith(normalizedPhrase)) {
                                shouldExit = true;
                                break;
                            }
                        }
                    }
                    if (shouldExit) break;
                }
            }

            if (shouldExit) {
                // Completion detected - allow exit silently
                try { fs.unlinkSync(RALPH_STATE_FILE); } catch (e) {}
                process.exit(0);
            }
        }
    } catch (e) {
        // Error reading transcript - continue with loop
    }
} else if (transcriptPath) {
    // Transcript file not found - continue with loop anyway
    // This handles cases where the transcript file hasn't been created yet
}

// Continue loop - update iteration
const nextIteration = iteration + 1;

// Update state file
const newFrontmatter = frontmatter.replace(/iteration:\s*\d+/, `iteration: ${nextIteration}`);
const newState = `---\n${newFrontmatter}\n---\n\n${promptText}`;

try {
    fs.writeFileSync(RALPH_STATE_FILE, newState);
} catch (e) {
    // Failed to write state - allow exit
    process.exit(0);
}

// Build system message
let systemMsg;
if (completionPromise && completionPromise !== null) {
    systemMsg = `Ralph iteration ${nextIteration} | To stop: output <promise>${completionPromise}</promise> (ONLY when TRUE)`;
} else {
    // No explicit promise - show default phrases that will trigger completion
    const commonPhrases = DEFAULT_COMPLETION_PHRASES.slice(0, 8).join(', ');
    systemMsg = `Ralph iteration ${nextIteration} | Auto-stop phrases: ${commonPhrases} | To stop manually: output <promise>DONE</promise>`;
}

// Output JSON to block stop and feed prompt back
// CRITICAL: Only output valid JSON, nothing else to stdout
const output = {
    decision: 'block',
    reason: promptText,
    systemMessage: systemMsg
};

// Use process.stdout.write to avoid any extra newlines or encoding issues
process.stdout.write(JSON.stringify(output));
process.exit(0);
