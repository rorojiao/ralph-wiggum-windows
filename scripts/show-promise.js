#!/usr/bin/env node

/**
 * Display completion promise if set
 */

const fs = require('fs');
const f = '.claude/ralph-loop.local.md';

if (fs.existsSync(f)) {
    const c = fs.readFileSync(f, 'utf8');
    // Match completion_promise: "value" or completion_promise: value (but not null)
    const m = c.match(/completion_promise:\s*"([^"]+)"/);
    if (m && m[1] && m[1] !== 'null' && m[1].trim() !== '') {
        console.log('');
        console.log('═══════════════════════════════════════════════════════════');
        console.log('CRITICAL - Ralph Loop Completion Promise');
        console.log('═══════════════════════════════════════════════════════════');
        console.log('');
        console.log('To complete this loop, output this EXACT text:');
        console.log('  <promise>' + m[1] + '</promise>');
        console.log('');
        console.log('STRICT REQUIREMENTS: Output ONLY when statement is TRUE');
        console.log('═══════════════════════════════════════════════════════════');
    }
}
