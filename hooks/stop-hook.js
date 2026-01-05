#!/usr/bin/env node

/**
 * Ralph Wiggum Stop Hook - Pure Node.js implementation
 * Works on Windows without bash/WSL
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

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
    console.error('Ralph loop: State file corrupted');
    fs.unlinkSync(RALPH_STATE_FILE);
    process.exit(0);
}

const frontmatter = frontmatterMatch[1];
const promptText = frontmatterMatch[2].trim();

// Parse frontmatter values
let iteration = 0;
let maxIterations = 0;
let completionPromise = 'null';

const iterMatch = frontmatter.match(/iteration:\s*(\d+)/);
if (iterMatch) iteration = parseInt(iterMatch[1], 10);

const maxIterMatch = frontmatter.match(/max_iterations:\s*(\d+)/);
if (maxIterMatch) maxIterations = parseInt(maxIterMatch[1], 10);

const promiseMatch = frontmatter.match(/completion_promise:\s*"?([^"\n]+)"?/);
if (promiseMatch) completionPromise = promiseMatch[1].replace(/^["']|["']$/g, '');

// Check if max iterations reached
if (maxIterations > 0 && iteration >= maxIterations) {
    console.log(`Ralph loop: Max iterations (${maxIterations}) reached.`);
    fs.unlinkSync(RALPH_STATE_FILE);
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

            // Check for completion promise
            if (completionPromise !== 'null' && completionPromise) {
                const promiseTagMatch = lastOutput.match(/<promise>\s*([\s\S]*?)\s*<\/promise>/);
                if (promiseTagMatch) {
                    const promiseText = promiseTagMatch[1].trim().replace(/\s+/g, ' ');
                    const normalizedPromise = completionPromise.replace(/\s+/g, ' ');

                    if (promiseText === normalizedPromise) {
                        console.log(`Ralph loop: Detected <promise>${completionPromise}</promise>`);
                        fs.unlinkSync(RALPH_STATE_FILE);
                        process.exit(0);
                    }
                }
            }
        }
    } catch (e) {
        // Error reading transcript - continue with loop
    }
} else if (transcriptPath) {
    console.error(`Ralph loop: Transcript file not found at: ${transcriptPath}`);
    fs.unlinkSync(RALPH_STATE_FILE);
    process.exit(0);
}

// Continue loop - update iteration
const nextIteration = iteration + 1;

// Update state file
const newFrontmatter = frontmatter.replace(/iteration:\s*\d+/, `iteration: ${nextIteration}`);
const newState = `---\n${newFrontmatter}\n---\n\n${promptText}`;

fs.writeFileSync(RALPH_STATE_FILE, newState);

// Build system message
let systemMsg;
if (completionPromise !== 'null' && completionPromise) {
    systemMsg = `Ralph iteration ${nextIteration} | To stop: output <promise>${completionPromise}</promise> (ONLY when TRUE)`;
} else {
    systemMsg = `Ralph iteration ${nextIteration} | No completion promise set - loop runs infinitely`;
}

// Output JSON to block stop and feed prompt back
const output = {
    decision: 'block',
    reason: promptText,
    systemMessage: systemMsg
};

console.log(JSON.stringify(output));
process.exit(0);
