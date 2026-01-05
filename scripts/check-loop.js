#!/usr/bin/env node

/**
 * Check if Ralph loop is active
 */

const fs = require('fs');
const f = '.claude/ralph-loop.local.md';

if (fs.existsSync(f)) {
    const c = fs.readFileSync(f, 'utf8');
    const m = c.match(/iteration:\s*(\d+)/);
    console.log('FOUND_LOOP=true');
    console.log('ITERATION=' + (m ? m[1] : '1'));
} else {
    console.log('FOUND_LOOP=false');
}
