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
	"run-project-hook.sh"
)

# Files in ~/ (not ~/.claude/) that define personality
HOME_MANAGED_ITEMS=(
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

Profiling:
  profile                          Compare all profiles (tokens, plugins, capabilities)
  profile --detail <branch>        Token breakdown and cost estimate for one profile
  profile --compare <a> <b>        Side-by-side diff of two profiles

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

# ─── Profiler ─────────────────────────────────────────────────────────────────

# Gather profile metrics for a branch. Outputs eval-able key=value pairs.
# Usage: eval "$(_profile_gather <branch>)"
# Safety: All string values are shlex.quote()'d to prevent injection.
_profile_gather() {
	local branch="$1"
	python3 - "$branch" "$REPO_DIR" <<'PYEOF'
import json, subprocess, sys, shlex

def git_show(branch, path):
    try:
        result = subprocess.run(
            ['git', 'show', f'{branch}:{path}'],
            capture_output=True, text=True, timeout=5
        )
        return result.stdout if result.returncode == 0 else ''
    except Exception:
        return ''

def char_tokens(text):
    return len(text) // 4

def safe(val):
    return shlex.quote(str(val))

try:
    branch = sys.argv[1]
    repo_dir = sys.argv[2]

    # Profile manifest
    profile_raw = git_show(branch, 'profile.json')
    if profile_raw:
        profile = json.loads(profile_raw)
        name = profile.get('name', branch)
        description = profile.get('description', '')
        author = profile.get('author', '')
        category = profile.get('category', 'unknown')
        tags = ','.join(profile.get('tags', []))
        capabilities = profile.get('capabilities', [])
    else:
        name = branch
        description = ''
        author = ''
        category = 'unknown'
        tags = ''
        capabilities = []

    # CLAUDE.md tokens
    claude_md = git_show(branch, 'claude/CLAUDE.md')
    claude_md_tokens = char_tokens(claude_md)

    # settings.json — extract enabled plugins
    settings_raw = git_show(branch, 'claude/settings.json')
    enabled_plugins = []
    settings_tokens = char_tokens(settings_raw)
    if settings_raw:
        try:
            settings = json.loads(settings_raw)
            ep = settings.get('enabledPlugins', {})
            enabled_plugins = [k.split('@')[0] for k, v in ep.items() if v]
        except json.JSONDecodeError:
            pass

    # MEMORY.md tokens
    memory_md = git_show(branch, 'claude/MEMORY.md')
    memory_tokens = char_tokens(memory_md)

    # Plugin metadata (always read from main branch)
    plugin_meta_raw = git_show('main', 'plugin-metadata.json')
    plugin_meta = {}
    if plugin_meta_raw:
        try:
            plugin_meta = json.loads(plugin_meta_raw)
        except json.JSONDecodeError:
            pass

    total_skills = 0
    total_mcp_tools = 0
    total_listing_tokens = 0
    plugin_details = []
    for pname in enabled_plugins:
        meta = plugin_meta.get(pname, {})
        skills = meta.get('skills', 0)
        mcp_tools = meta.get('mcp_tools', 0)
        lsp = meta.get('lsp_servers', 0)
        listing = meta.get('listing_tokens', 0)
        desc = meta.get('description', '')
        total_skills += skills
        total_mcp_tools += mcp_tools
        total_listing_tokens += listing
        plugin_details.append(f'{pname}|{skills}|{mcp_tools}|{lsp}|{listing}|{desc}')

    # User skills (count entries in claude/skills/)
    try:
        user_skills_raw = subprocess.run(
            ['git', 'ls-tree', '--name-only', f'{branch}:claude/skills/'],
            capture_output=True, text=True, timeout=5
        )
        user_skills = [s for s in user_skills_raw.stdout.strip().split('\n') if s] if user_skills_raw.returncode == 0 else []
    except Exception:
        user_skills = []
    user_skills_count = len(user_skills)
    user_skills_tokens = user_skills_count * 10  # ~40 chars / 4

    # Other tokens (keybindings, hooks, etc.)
    other_tokens = 0
    for path in ['claude/keybindings.json']:
        content = git_show(branch, path)
        if content:
            other_tokens += char_tokens(content)

    # Total profile overhead
    total_tokens = claude_md_tokens + settings_tokens + memory_tokens + total_listing_tokens + user_skills_tokens + other_tokens

    # Output as shell variables (all strings shlex.quote'd)
    print(f'P_NAME={safe(name)}')
    print(f'P_DESC={safe(description)}')
    print(f'P_AUTHOR={safe(author)}')
    print(f'P_CATEGORY={safe(category)}')
    print(f'P_TAGS={safe(tags)}')
    print(f'P_CLAUDE_MD_TOKENS={claude_md_tokens}')
    print(f'P_SETTINGS_TOKENS={settings_tokens}')
    print(f'P_MEMORY_TOKENS={memory_tokens}')
    print(f'P_LISTING_TOKENS={total_listing_tokens}')
    print(f'P_USER_SKILLS_TOKENS={user_skills_tokens}')
    print(f'P_OTHER_TOKENS={other_tokens}')
    print(f'P_TOTAL_TOKENS={total_tokens}')
    print(f'P_PLUGIN_COUNT={len(enabled_plugins)}')
    print(f'P_TOTAL_SKILLS={total_skills}')
    print(f'P_TOTAL_MCP_TOOLS={total_mcp_tools}')
    print(f'P_USER_SKILLS_COUNT={user_skills_count}')
    print(f'P_CAPS={safe(",".join(capabilities))}')
    print(f'P_CAPS_COUNT={len(capabilities)}')
    print(f'P_PLUGINS_DETAIL={safe(";".join(plugin_details))}')
    print(f'P_USER_SKILLS_LIST={safe(",".join(user_skills))}')

except Exception as e:
    # Always exit 0 — output safe defaults so eval doesn't break
    import shlex as _s
    print(f'P_NAME={_s.quote(sys.argv[1] if len(sys.argv) > 1 else "unknown")}')
    print('P_DESC=\'\'')
    print('P_AUTHOR=\'\'')
    print('P_CATEGORY=\'unknown\'')
    print('P_TAGS=\'\'')
    for var in ['P_CLAUDE_MD_TOKENS', 'P_SETTINGS_TOKENS', 'P_MEMORY_TOKENS',
                'P_LISTING_TOKENS', 'P_USER_SKILLS_TOKENS', 'P_OTHER_TOKENS',
                'P_TOTAL_TOKENS', 'P_PLUGIN_COUNT', 'P_TOTAL_SKILLS',
                'P_TOTAL_MCP_TOOLS', 'P_USER_SKILLS_COUNT', 'P_CAPS_COUNT']:
        print(f'{var}=0')
    print('P_CAPS=\'\'')
    print('P_PLUGINS_DETAIL=\'\'')
    print('P_USER_SKILLS_LIST=\'\'')
PYEOF
}

# Read pricing from benchmarks/pricing.json (on main branch).
# Outputs: PRICE_CACHE_READ, PRICE_CACHE_MISS, PRICE_MODEL
_profile_read_pricing() {
	eval "$(python3 - <<'PYEOF'
import json, subprocess, shlex
try:
    raw = subprocess.run(['git', 'show', 'main:benchmarks/pricing.json'],
        capture_output=True, text=True, timeout=5).stdout
    data = json.loads(raw)
    model = data.get('default_model', 'opus-4.6')
    m = data['models'][model]
    print(f'PRICE_CACHE_READ={m["cache_read_per_mtok"]}')
    print(f'PRICE_CACHE_MISS={m["cache_miss_per_mtok"]}')
    print(f'PRICE_MODEL={shlex.quote(model)}')
except Exception:
    print('PRICE_CACHE_READ=0.50')
    print('PRICE_CACHE_MISS=5.00')
    print("PRICE_MODEL='opus-4.6'")
PYEOF
)"
}

# Read base overhead total from benchmarks/base-overhead.json (on main branch).
_profile_read_base_overhead() {
	python3 - <<'PYEOF'
import json, subprocess
try:
    raw = subprocess.run(['git', 'show', 'main:benchmarks/base-overhead.json'],
        capture_output=True, text=True, timeout=5).stdout
    data = json.loads(raw)
    print(data['base_tokens']['total'])
except Exception:
    print('13000')
PYEOF
}

# Comparison table (default mode)
_profile_table() {
	local branches
	branches="$(git -C "$REPO_DIR" branch --list --no-color 2>/dev/null | sed 's/^[* ] //' | sort)"

	if [ -z "$branches" ]; then
		echo "No branches found."
		return 1
	fi

	local base_overhead
	base_overhead="$(_profile_read_base_overhead)"

	# Gather data for all branches
	local -a names=() categories=() tokens=() plugins=() skills=() mcps=() uskills=() all_caps=()
	while IFS= read -r branch; do
		[ -z "$branch" ] && continue
		eval "$(_profile_gather "$branch")"
		names+=("$P_NAME")
		categories+=("$P_CATEGORY")
		tokens+=("$P_TOTAL_TOKENS")
		plugins+=("$P_PLUGIN_COUNT")
		skills+=("$P_TOTAL_SKILLS")
		mcps+=("$P_TOTAL_MCP_TOOLS")
		uskills+=("$P_USER_SKILLS_COUNT")
		all_caps+=("$P_CAPS")
	done <<< "$branches"

	local count="${#names[@]}"

	echo ""
	echo "Claude Personalities — Profile Comparison"
	printf '═%.0s' {1..78}; echo ""
	echo ""
	printf "  %-14s %-12s %8s  %7s  %6s  %9s  %11s\n" \
		"Profile" "Category" "Tokens†" "Plugins" "Skills" "MCP Tools" "User Skills"
	printf '  '; printf '─%.0s' {1..76}; echo ""

	for ((i=0; i<count; i++)); do
		local tok_fmt="${tokens[$i]}"
		printf "  %-14s %-12s %8s  %7s  %6s  %9s  %11s\n" \
			"${names[$i]}" "${categories[$i]}" "$tok_fmt" \
			"${plugins[$i]}" "${skills[$i]}" "${mcps[$i]}" "${uskills[$i]}"
	done

	echo ""
	echo "  † Estimated per-turn system prompt overhead (chars / 4). Does not include"
	echo "    Claude Code base overhead (~${base_overhead} tokens shared by all profiles)."

	# Capability matrix — capabilities read from main branch
	local cap_names
	cap_names="$(python3 - <<'PYEOF'
import json, subprocess
try:
    raw = subprocess.run(['git', 'show', 'main:capabilities.json'],
        capture_output=True, text=True, timeout=5).stdout
    caps = json.loads(raw)
    for name in caps:
        print(name)
except Exception:
    pass
PYEOF
)"

	if [ -n "$cap_names" ]; then
		echo ""
		echo "  Capability Matrix"
		printf '  '; printf '─%.0s' {1..76}; echo ""

		# Header row with branch names
		printf "  %-24s" ""
		for ((i=0; i<count; i++)); do
			printf " %-12s" "${names[$i]}"
		done
		echo ""

		# One row per capability
		while IFS= read -r cap; do
			[ -z "$cap" ] && continue
			local display_name
			display_name="$(echo "$cap" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')"
			printf "  %-24s" "$display_name"
			for ((i=0; i<count; i++)); do
				if echo ",${all_caps[$i]}," | grep -q ",$cap,"; then
					printf " %-12s" "✓"
				else
					printf " %-12s" "—"
				fi
			done
			echo ""
		done <<< "$cap_names"
	fi

	echo ""
}

# Detail view for a single branch
_profile_detail() {
	local branch="$1"

	if ! git -C "$REPO_DIR" rev-parse --verify "$branch" &>/dev/null; then
		echo "Branch '$branch' not found."
		return 1
	fi

	eval "$(_profile_gather "$branch")"
	_profile_read_pricing
	local base_overhead
	base_overhead="$(_profile_read_base_overhead)"
	local total_with_base=$((P_TOTAL_TOKENS + base_overhead))

	echo ""
	echo "Profile: $P_NAME ($P_CATEGORY)"
	if [ -n "$P_DESC" ]; then
		echo "\"$P_DESC\""
	fi
	if [ -n "$P_AUTHOR" ]; then
		echo "Author: $P_AUTHOR"
	fi
	printf '═%.0s' {1..78}; echo ""
	echo ""

	# Token breakdown with bar chart
	echo "Token Breakdown (estimated per-turn overhead)"
	printf '─%.0s' {1..78}; echo ""

	# Build breakdown items — listing_tokens already includes skill + MCP + LSP overhead
	local -a labels=() values=()
	labels+=("CLAUDE.md"); values+=("$P_CLAUDE_MD_TOKENS")
	labels+=("Plugin listings ($P_PLUGIN_COUNT plugins)"); values+=("$P_LISTING_TOKENS")
	labels+=("MEMORY.md"); values+=("$P_MEMORY_TOKENS")
	labels+=("settings.json"); values+=("$P_SETTINGS_TOKENS")
	labels+=("User skills ($P_USER_SKILLS_COUNT)"); values+=("$P_USER_SKILLS_TOKENS")
	labels+=("Other (keybindings, hooks)"); values+=("$P_OTHER_TOKENS")

	local bar_width=20
	for ((i=0; i<${#labels[@]}; i++)); do
		local val="${values[$i]}"
		[ "$val" -eq 0 ] 2>/dev/null && continue
		local pct=0
		if [ "$P_TOTAL_TOKENS" -gt 0 ]; then
			pct=$(( (val * 100) / P_TOTAL_TOKENS ))
		fi
		local filled=$(( (pct * bar_width) / 100 ))
		local empty=$(( bar_width - filled ))
		local bar=""
		for ((j=0; j<filled; j++)); do bar+="█"; done
		for ((j=0; j<empty; j++)); do bar+="░"; done
		printf "  %-38s %5d tokens   %s %3d%%\n" "${labels[$i]}" "$val" "$bar" "$pct"
	done

	printf '  '; printf '─%.0s' {1..76}; echo ""
	printf "  %-38s %5d tokens\n" "TOTAL (profile overhead)" "$P_TOTAL_TOKENS"
	printf "  %-38s %5d tokens\n" "+ Base CC overhead" "$base_overhead"
	printf "  %-38s %5d tokens\n" "= Estimated total prompt" "$total_with_base"
	echo ""

	# Cost estimate
	echo "Cost Estimate (per-turn, $PRICE_MODEL cache-read rates)"
	printf '─%.0s' {1..78}; echo ""

	python3 - "$total_with_base" "$PRICE_CACHE_READ" "$PRICE_CACHE_MISS" <<'PYEOF'
import sys
tokens = int(sys.argv[1])
cache_read = float(sys.argv[2])
cache_miss = float(sys.argv[3])
cost_hit = tokens * cache_read / 1_000_000
cost_miss = tokens * cache_miss / 1_000_000
print(f'  Per turn (cache hit):     ${cost_hit:.4f}')
print(f'  Per turn (cache miss):    ${cost_miss:.4f}')
PYEOF
	echo ""

	# Plugin inventory
	if [ "$P_PLUGIN_COUNT" -gt 0 ]; then
		echo "Plugins ($P_PLUGIN_COUNT enabled)"
		printf '─%.0s' {1..78}; echo ""

		IFS=';' read -ra plugin_arr <<< "$P_PLUGINS_DETAIL"
		for entry in "${plugin_arr[@]}"; do
			IFS='|' read -r pname pskills pmcp plsp plisting pdesc <<< "$entry"
			local tools_str=""
			if [ "${pmcp:-0}" -gt 0 ]; then
				tools_str="$pmcp MCP tools"
			elif [ "${plsp:-0}" -gt 0 ]; then
				tools_str="$plsp LSP server"
			else
				tools_str="0 MCP tools"
			fi
			printf "  %-20s %2s skills  %12s   ~%s listing tokens\n" \
				"$pname" "$pskills" "$tools_str" "$plisting"
		done
		echo ""
	fi

	# User skills
	if [ "$P_USER_SKILLS_COUNT" -gt 0 ]; then
		echo "User Skills ($P_USER_SKILLS_COUNT)"
		printf '─%.0s' {1..78}; echo ""
		echo "  $(echo "$P_USER_SKILLS_LIST" | tr ',' ', ')"
		echo ""
	fi

	# Capabilities
	if [ "$P_CAPS_COUNT" -gt 0 ]; then
		echo "Capabilities ($P_CAPS_COUNT declared)"
		printf '─%.0s' {1..78}; echo ""
		echo "  ✓ $(echo "$P_CAPS" | tr ',' ', ')"
		echo ""
	elif [ "$P_CATEGORY" = "unknown" ]; then
		echo "Capabilities: undeclared (no profile.json)"
		echo ""
	fi
}

# Side-by-side comparison of two branches
_profile_compare() {
	local branch_a="$1"
	local branch_b="$2"

	for b in "$branch_a" "$branch_b"; do
		if ! git -C "$REPO_DIR" rev-parse --verify "$b" &>/dev/null; then
			echo "Branch '$b' not found."
			return 1
		fi
	done

	eval "$(_profile_gather "$branch_a")"
	local a_name="$P_NAME" a_tokens="$P_TOTAL_TOKENS" a_plugins="$P_PLUGIN_COUNT"
	local a_skills="$P_TOTAL_SKILLS" a_mcps="$P_TOTAL_MCP_TOOLS"
	local a_uskills="$P_USER_SKILLS_COUNT" a_caps="$P_CAPS"

	eval "$(_profile_gather "$branch_b")"
	local b_name="$P_NAME" b_tokens="$P_TOTAL_TOKENS" b_plugins="$P_PLUGIN_COUNT"
	local b_skills="$P_TOTAL_SKILLS" b_mcps="$P_TOTAL_MCP_TOOLS"
	local b_uskills="$P_USER_SKILLS_COUNT" b_caps="$P_CAPS"

	_profile_read_pricing
	local base_overhead
	base_overhead="$(_profile_read_base_overhead)"

	echo ""
	echo "Comparing: $a_name vs $b_name"
	printf '═%.0s' {1..78}; echo ""
	echo ""

	# Print comparison rows via python for reliable formatting
	python3 - "$a_name" "$b_name" "$a_tokens" "$b_tokens" "$a_plugins" "$b_plugins" \
		"$a_skills" "$b_skills" "$a_mcps" "$b_mcps" "$a_uskills" "$b_uskills" \
		"$base_overhead" "$PRICE_CACHE_READ" <<'PYEOF'
import sys
a_name, b_name = sys.argv[1], sys.argv[2]
a_tok, b_tok = int(sys.argv[3]), int(sys.argv[4])
a_plug, b_plug = int(sys.argv[5]), int(sys.argv[6])
a_skill, b_skill = int(sys.argv[7]), int(sys.argv[8])
a_mcp, b_mcp = int(sys.argv[9]), int(sys.argv[10])
a_usk, b_usk = int(sys.argv[11]), int(sys.argv[12])
base = int(sys.argv[13])
price = float(sys.argv[14])

def fmt_delta(a, b):
    d = a - b
    return f'+{d}' if d >= 0 else str(d)

a_cost = (a_tok + base) * price / 1_000_000
b_cost = (b_tok + base) * price / 1_000_000
d_cost = a_cost - b_cost
a_cost_100 = a_cost * 100
b_cost_100 = b_cost * 100
d_cost_100 = d_cost * 100

print(f'  {"":24s} {a_name:>12s} {b_name:>12s} {"delta":>12s}')
print(f'  {"─" * 60}')
print(f'  {"Estimated tokens":24s} {a_tok:>12,d} {b_tok:>12,d} {fmt_delta(a_tok, b_tok):>12s}')
print(f'  {"Plugins":24s} {a_plug:>12d} {b_plug:>12d} {fmt_delta(a_plug, b_plug):>12s}')
print(f'  {"Skills":24s} {a_skill:>12d} {b_skill:>12d} {fmt_delta(a_skill, b_skill):>12s}')
print(f'  {"MCP tools":24s} {a_mcp:>12d} {b_mcp:>12d} {fmt_delta(a_mcp, b_mcp):>12s}')
print(f'  {"User skills":24s} {a_usk:>12d} {b_usk:>12d} {fmt_delta(a_usk, b_usk):>12s}')
d_sign = '+' if d_cost >= 0 else ''
d100_sign = '+' if d_cost_100 >= 0 else ''
print(f'  {"Cost/turn (cache hit)":24s} {"$" + f"{a_cost:.4f}":>12s} {"$" + f"{b_cost:.4f}":>12s} {"$" + d_sign + f"{d_cost:.4f}":>12s}')
print(f'  {"Cost/100 turns":24s} {"$" + f"{a_cost_100:.2f}":>12s} {"$" + f"{b_cost_100:.2f}":>12s} {"$" + d100_sign + f"{d_cost_100:.2f}":>12s}')
PYEOF

	# Capability diff
	echo ""
	local only_a="" only_b=""
	local -a caps_a=() caps_b=()
	[ -n "$a_caps" ] && IFS=',' read -ra caps_a <<< "$a_caps"
	[ -n "$b_caps" ] && IFS=',' read -ra caps_b <<< "$b_caps"

	for cap in ${caps_a[@]+"${caps_a[@]}"}; do
		[ -z "$cap" ] && continue
		if ! echo ",$b_caps," | grep -q ",$cap,"; then
			only_a="${only_a:+$only_a, }$cap"
		fi
	done
	for cap in ${caps_b[@]+"${caps_b[@]}"}; do
		[ -z "$cap" ] && continue
		if ! echo ",$a_caps," | grep -q ",$cap,"; then
			only_b="${only_b:+$only_b, }$cap"
		fi
	done

	if [ -n "$only_a" ]; then
		echo "  Capabilities only in $a_name:"
		echo "    + $only_a"
	fi
	if [ -n "$only_b" ]; then
		echo "  Capabilities only in $b_name:"
		echo "    + $only_b"
	fi
	if [ -z "$only_a" ] && [ -z "$only_b" ]; then
		echo "  Both profiles have identical capabilities."
	fi

	echo ""
}

# Main dispatch for profile command
cmd_profile() {
	local mode="table"
	local detail_branch=""
	local compare_a="" compare_b=""

	while [ $# -gt 0 ]; do
		case "$1" in
			--detail)
				mode="detail"
				detail_branch="${2:-}"
				if [ -z "$detail_branch" ]; then
					echo "usage: ./setup.sh profile --detail <branch>"
					return 1
				fi
				shift 2
				;;
			--compare)
				mode="compare"
				compare_a="${2:-}"
				compare_b="${3:-}"
				if [ -z "$compare_a" ] || [ -z "$compare_b" ]; then
					echo "usage: ./setup.sh profile --compare <branch-a> <branch-b>"
					return 1
				fi
				shift 3
				;;
			*)
				shift
				;;
		esac
	done

	if ! command -v python3 &>/dev/null; then
		echo "python3 is required for the profiler. It ships with macOS."
		return 1
	fi

	case "$mode" in
		table)   _profile_table ;;
		detail)  _profile_detail "$detail_branch" ;;
		compare) _profile_compare "$compare_a" "$compare_b" ;;
	esac
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
	profile)      shift; cmd_profile "$@" ;;
	*)            usage ;;
esac
