#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$REPO_DIR/_backups"
PACKAGE_DIR="$REPO_DIR/claude"
HOME_PACKAGE_DIR="$REPO_DIR/home"

# Files/dirs inside ~/.claude/ that define personality
MANAGED_ITEMS=(
	"CLAUDE.md"
	"settings.json"
	"settings.local.json"
	"MEMORY.md"
	"keybindings.json"
	"agents"
	"skills"
	"rules"
	"commands"
	"mcp.json"
	"statusline-command.sh"
	"statusline-config.txt"
	"fetch-claude-usage.swift"
	"run-project-hook.sh"
)

# Files in ~/ (not ~/.claude/) that define personality
HOME_MANAGED_ITEMS=(
	".claude.json"
)

# Runtime/ephemeral items — never personality, never managed
KNOWN_RUNTIME=(
	"projects"
	"history.jsonl"
	"debug"
	"debug.log"
	"plans"
	"todos"
	"tasks"
	"teams"
	"sessions"
	"session-env"
	"shell-snapshots"
	"file-history"
	"paste-cache"
	"telemetry"
	"statsig"
	".statsig"
	"cache"
	"backups"
	"downloads"
	"plugins"
	"stats-cache.json"
	".DS_Store"
	".statusline-usage-cache"
)

VERSION_FILE="$REPO_DIR/.claude-code-version"

usage() {
	cat <<EOF
Usage: ./setup.sh <command>

Profile management:
  use <branch>    Switch to a profile (unlink, checkout, relink)
  current         Print active profile name
  list            List available profiles
  status          Show symlink health for all managed items

Setup:
  backup          Back up current ~/.claude/ personality files
  import          Import personality files from ~/.claude/ into this repo

Health:
  doctor          Full health check (prereqs, symlinks, drift, version)
  drift           Scan ~/.claude/ for unrecognized files
  changelog       Fetch Claude Code changelog, filter for config changes
  pin-version     Record current Claude Code version

EOF
}

# ─── Symlink engine ──────────────────────────────────────────────────────────

# Remove symlinks that point into THIS repo. Never touches real files.
unlink_profile() {
	# Items in ~/.claude/
	for item in "${MANAGED_ITEMS[@]}"; do
		local path="$CLAUDE_DIR/$item"
		if [ -L "$path" ]; then
			local target
			target="$(readlink "$path")"
			if [[ "$target" == "$PACKAGE_DIR"* ]]; then
				rm "$path"
			fi
		fi
	done

	# Items in ~/
	for item in "${HOME_MANAGED_ITEMS[@]}"; do
		local path="$HOME/$item"
		if [ -L "$path" ]; then
			local target
			target="$(readlink "$path")"
			if [[ "$target" == "$HOME_PACKAGE_DIR"* ]]; then
				rm "$path"
			fi
		fi
	done
}

# Create symlinks. Warns on conflicts (real file blocking). Skips missing items.
link_profile() {
	local conflicts=0

	# Items in ~/.claude/
	for item in "${MANAGED_ITEMS[@]}"; do
		local src="$PACKAGE_DIR/$item"
		local dst="$CLAUDE_DIR/$item"
		[ -e "$src" ] || continue

		if [ -e "$dst" ] && [ ! -L "$dst" ]; then
			echo "  ! conflict: $item exists as real file in ~/.claude/ (not overwriting)"
			conflicts=$((conflicts + 1))
			continue
		fi
		[ -L "$dst" ] && rm "$dst"
		ln -s "$src" "$dst"
	done

	# Items in ~/
	for item in "${HOME_MANAGED_ITEMS[@]}"; do
		local src="$HOME_PACKAGE_DIR/$item"
		local dst="$HOME/$item"
		[ -e "$src" ] || continue

		if [ -e "$dst" ] && [ ! -L "$dst" ]; then
			echo "  ! conflict: ~/$item exists as real file (not overwriting)"
			conflicts=$((conflicts + 1))
			continue
		fi
		[ -L "$dst" ] && rm "$dst"
		ln -s "$src" "$dst"
	done

	if [ "$conflicts" -gt 0 ]; then
		echo ""
		echo "  $conflicts conflict(s). Run './setup.sh backup' first, then remove the real files."
	fi
}

# ─── Commands ────────────────────────────────────────────────────────────────

cmd_use() {
	local branch="${1:-}"
	if [ -z "$branch" ]; then
		echo "usage: ./setup.sh use <branch>"
		return 1
	fi

	# Check for dirty working tree before doing anything
	local dirty
	dirty="$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)"
	if [ -n "$dirty" ]; then
		echo "Uncommitted changes in profile repo. Commit or stash before switching."
		echo ""
		git -C "$REPO_DIR" status --short
		return 1
	fi

	local prev_branch
	prev_branch="$(git -C "$REPO_DIR" branch --show-current 2>/dev/null || echo "")"

	# Unlink current profile
	unlink_profile

	# Attempt checkout
	if ! git -C "$REPO_DIR" checkout "$branch" 2>/dev/null; then
		echo "Failed to checkout branch '$branch'."
		# Re-link previous profile to avoid leaving user with no symlinks
		if [ -n "$prev_branch" ]; then
			git -C "$REPO_DIR" checkout "$prev_branch" 2>/dev/null
			link_profile
			echo "Restored previous profile: $prev_branch"
		fi
		return 1
	fi

	# Link new profile
	link_profile
	echo "Switched to profile: $branch"
}

cmd_current() {
	git -C "$REPO_DIR" branch --show-current 2>/dev/null || echo "none (detached HEAD)"
}

cmd_list() {
	local current
	current="$(git -C "$REPO_DIR" branch --show-current 2>/dev/null || echo "")"
	git -C "$REPO_DIR" branch --list --no-color 2>/dev/null | while read -r line; do
		local name
		name="$(echo "$line" | sed 's/^[* ] //')"
		if [ "$name" = "$current" ]; then
			echo "* $name (active)"
		else
			echo "  $name"
		fi
	done
}

cmd_backup() {
	local timestamp
	timestamp="$(date +%Y%m%d-%H%M%S)"
	local dest="$BACKUP_DIR/$timestamp"
	mkdir -p "$dest"

	local count=0

	# Backup ~/.claude/ items
	for item in "${MANAGED_ITEMS[@]}"; do
		local src="$CLAUDE_DIR/$item"
		if [ -e "$src" ] || [ -L "$src" ]; then
			if [ -L "$src" ]; then
				# Copy the symlink target, not the symlink itself
				cp -a "$(readlink "$src")" "$dest/$item" 2>/dev/null || cp -a "$src" "$dest/$item"
			else
				cp -a "$src" "$dest/$item"
			fi
			count=$((count + 1))
		fi
	done

	# Backup ~/ items
	mkdir -p "$dest/_home"
	for item in "${HOME_MANAGED_ITEMS[@]}"; do
		local src="$HOME/$item"
		if [ -e "$src" ] || [ -L "$src" ]; then
			if [ -L "$src" ]; then
				cp -a "$(readlink "$src")" "$dest/_home/$item" 2>/dev/null || cp -a "$src" "$dest/_home/$item"
			else
				cp -a "$src" "$dest/_home/$item"
			fi
			count=$((count + 1))
		fi
	done

	echo "Backed up $count items to _backups/$timestamp/"
}

cmd_import() {
	mkdir -p "$PACKAGE_DIR"
	mkdir -p "$HOME_PACKAGE_DIR"
	local count=0

	# Import ~/.claude/ items
	for item in "${MANAGED_ITEMS[@]}"; do
		local src="$CLAUDE_DIR/$item"
		local dst="$PACKAGE_DIR/$item"

		if [ -e "$src" ]; then
			# Skip if already a symlink pointing into this repo
			if [ -L "$src" ]; then
				local target
				target="$(readlink "$src")"
				if [[ "$target" == "$PACKAGE_DIR"* ]]; then
					echo "  skip $item (already linked to this repo)"
					continue
				fi
			fi

			cp -a "$src" "$dst"
			echo "  imported $item"
			count=$((count + 1))
		fi
	done

	# Import ~/ items
	for item in "${HOME_MANAGED_ITEMS[@]}"; do
		local src="$HOME/$item"
		local dst="$HOME_PACKAGE_DIR/$item"

		if [ -e "$src" ]; then
			if [ -L "$src" ]; then
				local target
				target="$(readlink "$src")"
				if [[ "$target" == "$HOME_PACKAGE_DIR"* ]]; then
					echo "  skip ~/$item (already linked to this repo)"
					continue
				fi
			fi

			cp -a "$src" "$dst"
			echo "  imported ~/$item"
			count=$((count + 1))
		fi
	done

	echo ""
	echo "Imported $count items."
	echo ""
	echo "Next steps:"
	echo "  git add -A && git commit -m 'profile: base (imported from current config)'"
	echo "  ./setup.sh use main  # activate symlinks"
}

cmd_status() {
	echo "Profile: $(cmd_current)"
	echo ""
	echo "~/.claude/ items:"

	for item in "${MANAGED_ITEMS[@]}"; do
		local path="$CLAUDE_DIR/$item"
		if [ -L "$path" ]; then
			local target
			target="$(readlink "$path")"
			if [[ "$target" == "$PACKAGE_DIR"* ]]; then
				printf "  + %-28s linked\n" "$item"
			else
				printf "  ? %-28s linked (elsewhere: %s)\n" "$item" "$target"
			fi
		elif [ -e "$path" ]; then
			printf "  ! %-28s real file (not managed)\n" "$item"
		else
			printf "  - %-28s absent\n" "$item"
		fi
	done

	echo ""
	echo "~/ items:"

	for item in "${HOME_MANAGED_ITEMS[@]}"; do
		local path="$HOME/$item"
		if [ -L "$path" ]; then
			local target
			target="$(readlink "$path")"
			if [[ "$target" == "$HOME_PACKAGE_DIR"* ]]; then
				printf "  + %-28s linked\n" "$item"
			else
				printf "  ? %-28s linked (elsewhere: %s)\n" "$item" "$target"
			fi
		elif [ -e "$path" ]; then
			printf "  ! %-28s real file (not managed)\n" "$item"
		else
			printf "  - %-28s absent\n" "$item"
		fi
	done
}

cmd_doctor() {
	echo "=== Prerequisites ==="
	echo ""

	local ok=1
	if command -v git &>/dev/null; then
		echo "  + git $(git --version | cut -d' ' -f3)"
	else
		echo "  ! git not found" && ok=0
	fi

	if [ -d "$CLAUDE_DIR" ]; then
		echo "  + ~/.claude/ exists"
	else
		echo "  ! ~/.claude/ not found" && ok=0
	fi

	local cc_version=""
	if command -v claude &>/dev/null; then
		cc_version="$(claude --version 2>/dev/null | head -1 || echo "")"
		echo "  + claude CLI: $cc_version"
	else
		echo "  ? claude CLI not in PATH"
	fi

	echo ""
	echo "=== Profile Status ==="
	echo ""

	cmd_status

	echo ""
	echo "=== Drift Detection ==="
	echo ""

	cmd_drift

	# Version tracking
	if [ -n "$cc_version" ] && [ -f "$VERSION_FILE" ]; then
		local last_version
		last_version="$(cat "$VERSION_FILE")"
		if [ "$last_version" != "$cc_version" ]; then
			echo ""
			echo "=== Version Change ==="
			echo ""
			echo "  Claude Code updated: $last_version -> $cc_version"
			echo "  Run './setup.sh changelog' to check for config changes."
		fi
	elif [ -n "$cc_version" ] && [ ! -f "$VERSION_FILE" ]; then
		echo ""
		echo "  Tip: Run './setup.sh pin-version' to start tracking version changes."
	fi

	echo ""
	if [ "$ok" -eq 1 ]; then
		echo "Done."
	else
		echo "Fix prerequisite issues above."
	fi
}

cmd_drift() {
	if [ ! -d "$CLAUDE_DIR" ]; then
		echo "  No ~/.claude/ directory found."
		return
	fi

	local unknown_count=0
	local unknown_items=()

	for entry in "$CLAUDE_DIR"/*; do
		[ -e "$entry" ] || continue
		local name
		name="$(basename "$entry")"

		# Skip hidden files
		[[ "$name" == .* ]] && continue

		# Check MANAGED_ITEMS
		local is_managed=0
		for m in "${MANAGED_ITEMS[@]}"; do
			if [ "$name" = "$m" ]; then
				is_managed=1
				break
			fi
		done
		[ "$is_managed" -eq 1 ] && continue

		# Check KNOWN_RUNTIME
		local is_runtime=0
		for r in "${KNOWN_RUNTIME[@]}"; do
			if [ "$name" = "$r" ]; then
				is_runtime=1
				break
			fi
		done
		[ "$is_runtime" -eq 1 ] && continue

		unknown_items+=("$name")
		unknown_count=$((unknown_count + 1))
	done

	if [ "$unknown_count" -eq 0 ]; then
		echo "  + No unknown files in ~/.claude/"
	else
		echo "  ! Found $unknown_count unrecognized item(s) in ~/.claude/:"
		echo ""
		for item in "${unknown_items[@]}"; do
			local path="$CLAUDE_DIR/$item"
			if [ -d "$path" ]; then
				local fcount
				fcount="$(find "$path" -type f 2>/dev/null | wc -l | tr -d ' ')"
				printf "    %-28s  (dir, %s files)\n" "$item/" "$fcount"
			else
				local size
				size="$(wc -c < "$path" 2>/dev/null | tr -d ' ')"
				printf "    %-28s  (file, %s bytes)\n" "$item" "$size"
			fi
		done
		echo ""
		echo "  Add to MANAGED_ITEMS or KNOWN_RUNTIME in setup.sh."
	fi
}

cmd_changelog() {
	local CHANGELOG_URL="https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"

	echo "Fetching Claude Code changelog..."
	echo ""

	local tmpfile
	tmpfile="$(mktemp)"
	if ! curl -fsSL "$CHANGELOG_URL" -o "$tmpfile" 2>/dev/null; then
		echo "  ! Failed to fetch changelog."
		rm -f "$tmpfile"
		return 1
	fi

	echo "Config-relevant changes (last 10 versions):"
	echo ""

	awk '
		/^## [0-9]/ { version_count++; current_version=$0 }
		version_count > 10 { exit }
		version_count >= 1 {
			if ($0 ~ /^## [0-9]/) {
				pending_header = $0
				printed_header = 0
			} else if (tolower($0) ~ /settings|claude\.md|directory|configuration|breaking|deprecated|agents|skills|rules|commands|mcp|hooks|permissions|memory|plugin|keybindings/) {
				if (!printed_header) {
					print pending_header
					printed_header = 1
				}
				print $0
			}
		}
	' "$tmpfile" | head -80

	echo ""
	rm -f "$tmpfile"
}

cmd_pin_version() {
	if ! command -v claude &>/dev/null; then
		echo "Claude CLI not found."
		return 1
	fi
	local version
	version="$(claude --version 2>/dev/null | head -1)"
	echo "$version" > "$VERSION_FILE"
	echo "Pinned: $version"
}

# ─── Dispatch ────────────────────────────────────────────────────────────────

case "${1:-}" in
	use)          cmd_use "${2:-}" ;;
	current)      cmd_current ;;
	list)         cmd_list ;;
	backup)       cmd_backup ;;
	import)       cmd_import ;;
	status)       cmd_status ;;
	doctor)       cmd_doctor ;;
	drift)        cmd_drift ;;
	changelog)    cmd_changelog ;;
	pin-version)  cmd_pin_version ;;
	*)            usage ;;
esac
