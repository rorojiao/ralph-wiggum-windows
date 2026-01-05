#!/usr/bin/env node

/**
 * Ralph Loop Setup - Cross-platform wrapper
 * Detects platform and calls the appropriate script (PowerShell or Bash)
 */

const { execSync } = require('child_process');
const path = require('path');

const isWindows = process.platform === 'win32';

// Get arguments (skip first two: node executable and script path)
const args = process.argv.slice(2);

function runSetup() {
    // Get plugin root - if CLAUDE_PLUGIN_ROOT is not set, go up one level from __dirname (scripts/)
    const pluginRoot = process.env.CLAUDE_PLUGIN_ROOT || path.join(__dirname, '..');
    let script, command;

    if (isWindows) {
        // Use PowerShell script on Windows
        script = path.join(pluginRoot, 'scripts', 'setup-ralph-loop.ps1');

        // Build PowerShell command using -Command instead of -File for better argument handling
        // Escape each argument properly for PowerShell
        const psArgs = args.map(arg => {
            // Escape for PowerShell: double quotes, backticks, etc.
            let escaped = arg.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
            return `"${escaped}"`;
        }).join(' ');

        command = `chcp 65001 >nul && powershell -NoProfile -ExecutionPolicy Bypass -Command "& '${script}' ${psArgs}"`;

        try {
            const result = execSync(command, {
                encoding: 'utf8',
                stdio: 'inherit',
                cwd: process.cwd(),
                env: { ...process.env, CLAUDE_PLUGIN_ROOT: pluginRoot }
            });
            process.exit(0);
        } catch (err) {
            process.exit(err.status || 1);
        }
    } else {
        // Use Bash script on Unix-like systems
        script = path.join(pluginRoot, 'scripts', 'setup-ralph-loop.sh');

        // Build bash command with proper argument quoting
        const bashArgs = args.map(arg => `'${arg.replace(/'/g, "'\\''")}'`).join(' ');

        command = `"${script}" ${bashArgs}`;

        try {
            const result = execSync(command, {
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
