#!/usr/bin/env bash
# install-git-hooks.sh — idempotent installer for the pre-commit grounding gate.
#
# Usage:
#   install-git-hooks.sh            # install (or report already-installed)
#   install-git-hooks.sh --force    # overwrite existing pre-commit (backed up to .bak)
#   install-git-hooks.sh --uninstall # remove if it's our symlink

set -euo pipefail

mode="install"
case "${1:-}" in
  --force)     mode="force" ;;
  --uninstall) mode="uninstall" ;;
  -h|--help)
    sed -n '2,8p' "$0"
    exit 0
    ;;
  "") ;;
  *)
    echo "unknown flag: $1" >&2
    exit 2
    ;;
esac

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$SKILL_DIR/../../.." && pwd)"
HOOK_SRC_REL=".claude/hooks/git-pre-commit-grounding.sh"
HOOK_SRC_ABS="$REPO_ROOT/$HOOK_SRC_REL"
HOOK_DST="$REPO_ROOT/.git/hooks/pre-commit"

if [[ ! -d "$REPO_ROOT/.git" ]]; then
  echo "error: $REPO_ROOT is not a git repo (no .git/)" >&2
  exit 1
fi
if [[ ! -f "$HOOK_SRC_ABS" ]]; then
  echo "error: hook source not found at $HOOK_SRC_ABS" >&2
  exit 1
fi
chmod +x "$HOOK_SRC_ABS" 2>/dev/null || true

# Compute the relative target the symlink will point at.
# .git/hooks/pre-commit  →  ../../.claude/hooks/git-pre-commit-grounding.sh
SYMLINK_TARGET="../../$HOOK_SRC_REL"

is_our_symlink() {
  [[ -L "$HOOK_DST" ]] || return 1
  local current
  current=$(readlink "$HOOK_DST" 2>/dev/null || echo "")
  [[ "$current" == "$SYMLINK_TARGET" ]]
}

case "$mode" in
  uninstall)
    if [[ ! -e "$HOOK_DST" && ! -L "$HOOK_DST" ]]; then
      echo "no pre-commit hook installed; nothing to remove."
      exit 0
    fi
    if is_our_symlink; then
      rm "$HOOK_DST"
      echo "uninstalled pre-commit grounding gate."
      exit 0
    fi
    echo "error: $HOOK_DST is not our symlink (target: $(readlink "$HOOK_DST" 2>/dev/null || echo 'regular file'))" >&2
    echo "refusing to remove a hook we did not install. Inspect manually." >&2
    exit 1
    ;;
  install|force)
    if is_our_symlink; then
      echo "already installed: $HOOK_DST → $SYMLINK_TARGET"
      exit 0
    fi
    if [[ -e "$HOOK_DST" || -L "$HOOK_DST" ]]; then
      if [[ "$mode" != "force" ]]; then
        existing=$(readlink "$HOOK_DST" 2>/dev/null || echo "(regular file)")
        cat >&2 <<EOF
$HOOK_DST already exists and points to $existing.
To preserve your existing hook, manually add a call to:
  bash \$CLAUDE_PROJECT_DIR/.claude/hooks/git-pre-commit-grounding.sh
inside it. Or run with --force to replace (your existing hook will be backed up to pre-commit.bak).
EOF
        exit 1
      fi
      mv "$HOOK_DST" "$HOOK_DST.bak"
      echo "backed up existing hook to $HOOK_DST.bak"
    fi
    ln -s "$SYMLINK_TARGET" "$HOOK_DST"
    echo "installed: $HOOK_DST → $SYMLINK_TARGET"
    echo "future \`git commit\` runs will check the curling-research pending log."
    exit 0
    ;;
esac
