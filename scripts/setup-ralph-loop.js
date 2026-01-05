#!/usr/bin/env node

/**
 * Ralph Loop Setup - Cross-platform wrapper
 * Reads arguments from environment variable if no arguments provided
 */

const { execSync } = require('child_process');
const path = require('path');

const isWindows = process.platform === 'win32';

// Get arguments from command line or environment variable
let args = process.argv.slice(2);

// Check for environment variable with prompt (set by command wrapper)
// The env var contains the main prompt/task description
if (process.env.RALPH_ARGS) {
    // Add the prompt from environment variable as a positional argument
    // This should come before any options like --max-iterations
    args.unshift(process.env.RALPH_ARGS);
}

function runSetup() {
    const pluginRoot = process.env.CLAUDE_PLUGIN_ROOT || path.join(__dirname, '..');
    let script, command;

    if (isWindows) {
        script = path.join(pluginRoot, 'scripts', 'setup-ralph-loop.ps1');

        // Build PowerShell command with all arguments as a single string
        const argsString = args.map(arg => {
            // Escape for PowerShell
            let escaped = arg.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/`/g, '``');
            return '"' + escaped + '"';
        }).join(' ');

        command = `powershell -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; & '${script}' ${argsString}"`;

        try {
            execSync(command, {
                encoding: 'utf8',
                stdio: 'inherit',
                cwd: process.cwd(),
                env: { ...process.env, CLAUDE_PLUGIN_ROOT: pluginRoot }
            });
            process.exit(0);
        } catch (err) {
            process.exit(0);
        }
    } else {
        script = path.join(pluginRoot, 'scripts', 'setup-ralph-loop.sh');

        const bashArgs = args.map(arg => `'${arg.replace(/'/g, "'\\''")}'`).join(' ');
        command = `"${script}" ${bashArgs}`;

        try {
            execSync(command, {
                encoding: 'utf8',
                stdio: 'inherit',
                cwd: process.cwd(),
                env: { ...process.env, CLAUDE_PLUGIN_ROOT: pluginRoot }
            });
            process.exit(0);
        } catch (err) {
            process.exit(err.status || 1);
        }
    }
}

runSetup();
