#!/usr/bin/env bash
# run-project-hook.sh
#
# Runs a .claude/helpers/* hook from the main git repo root.
# Worktree-safe: uses --git-common-dir to find the real repo regardless of
# which worktree (or the main checkout) the shell is currently in.
#
# Usage:
#   bash ~/.claude/run-project-hook.sh <script-name> [args...]
#
# Example:
#   bash ~/.claude/run-project-hook.sh auto-memory-hook.mjs sync
#   bash ~/.claude/run-project-hook.sh hook-handler.cjs session-end

COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null) || {
  # Not in a git repo — silently skip (non-blocking)
  exit 0
}

REPO_ROOT=$(cd "$COMMON_DIR/.." && pwd)

exec node "$REPO_ROOT/.claude/helpers/$1" "${@:2}"
