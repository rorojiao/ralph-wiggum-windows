---
description: "Cancel active Ralph Wiggum loop"
allowed-tools: ["Bash"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph

First, check if a Ralph loop is active:

```!
node "${CLAUDE_PLUGIN_ROOT}/scripts/check-loop.js"
```

Check the output above:

1. **If FOUND_LOOP=false**:
   - Say "No active Ralph loop found."

2. **If FOUND_LOOP=true**:
   - Remove the state file to cancel the loop:
     ```!
     node "${CLAUDE_PLUGIN_ROOT}/scripts/remove-loop.js"
     ```
   - Report: "Cancelled Ralph loop (was at iteration N)" where N is the ITERATION value from above.
