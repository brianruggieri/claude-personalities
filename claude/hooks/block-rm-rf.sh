#!/bin/bash
# PreToolUse hook: block rm -rf, suggest trash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
if echo "$COMMAND" | grep -qE 'rm\s+-(rf|fr)\s'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"BLOCKED: Use trash or mv instead of rm -rf. Confirm with user before deleting."}}'
fi
