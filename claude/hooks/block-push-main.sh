#!/bin/bash
# PreToolUse hook: block push to main/master, suggest PR
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
if echo "$COMMAND" | grep -qE 'git push.*(origin|upstream)\s+(main|master)'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"BLOCKED: Never push directly to main/master. Create a PR instead: gh pr create"}}'
fi
