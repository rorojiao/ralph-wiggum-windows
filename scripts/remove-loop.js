#!/usr/bin/env node

/**
 * Remove Ralph loop state file
 */

const fs = require('fs');
const f = '.claude/ralph-loop.local.md';

if (fs.existsSync(f)) {
    fs.unlinkSync(f);
    console.log('Removed state file');
} else {
    console.log('No state file found');
}
