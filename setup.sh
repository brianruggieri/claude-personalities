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

Metrics:
  snapshot                         Capture current session metrics for active profile
  snapshot --all                   Capture metrics for all projects

  Tip: Auto-capture with a SessionEnd hook in claude/settings.json:
    "hooks": { "SessionEnd": [{ "type": "command",
      "command": "~/git/claude_personalities/setup.sh snapshot --quiet" }] }

Benchmarking:
  benchmark                        Run all benchmark tasks against current profile
  benchmark --task <name>          Run a specific benchmark task
  benchmark --report               Show benchmark results across profiles
  benchmark --report --html        Generate interactive HTML dashboard

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

	# Session averages (if snapshot data exists)
	local session_data
	session_data="$(_session_averages)"
	if [ -n "$session_data" ]; then
		echo ""
		echo "  Session Averages (from _metrics/sessions/)"
		printf '  '; printf '─%.0s' {1..76}; echo ""
		printf "  %-14s %8s  %9s  %12s  %12s\n" \
			"Profile" "Sessions" "Avg Cost" "Avg Duration" "Avg Cache%"

		while IFS= read -r line; do
			[ -z "$line" ] && continue
			read -r prof sessions avg_cost avg_dur avg_cache <<< "$line"
			prof="$(echo "$prof" | tr -d "'")"
			local dur_min=$(( ${avg_dur%.*} / 60 ))
			local dur_sec=$(( ${avg_dur%.*} % 60 ))
			local dur_fmt="${dur_min}m ${dur_sec}s"
			local cache_pct
			cache_pct="$(python3 -c "print(f'{float(${avg_cache}) * 100:.1f}%')")"

			printf "  %-14s %8s  %9s  %12s  %12s\n" \
				"$prof" "$sessions" "\$${avg_cost}" "$dur_fmt" "$cache_pct"
		done <<< "$session_data"
	fi

	# Benchmark results (if data exists)
	local benchmarks_dir="$REPO_DIR/_metrics/benchmarks"
	if [ -d "$benchmarks_dir" ]; then
		local has_data
		has_data="$(find "$benchmarks_dir" -name '*.json' -print -quit 2>/dev/null)"
		if [ -n "$has_data" ]; then
			_benchmark_report
		fi
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

# ─── Session Snapshots ────────────────────────────────────────────────────────

# Capture session metrics from ~/.claude.json for the active profile.
# Usage: cmd_snapshot [--all] [--quiet]
cmd_snapshot() {
	local capture_all=0
	local quiet=0

	while [ $# -gt 0 ]; do
		case "$1" in
			--all)   capture_all=1; shift ;;
			--quiet) quiet=1; shift ;;
			*)       shift ;;
		esac
	done

	local profile
	profile="$(git -C "$REPO_DIR" branch --show-current 2>/dev/null || echo "unknown")"

	local claude_json="$HOME/.claude.json"
	if [ ! -f "$claude_json" ]; then
		[ "$quiet" -eq 0 ] && echo "No ~/.claude.json found. Run a Claude Code session first."
		return 1
	fi

	local metrics_dir="$REPO_DIR/_metrics/sessions/$profile"
	mkdir -p "$metrics_dir"

	python3 - "$claude_json" "$profile" "$capture_all" "$quiet" "$PWD" "$metrics_dir" <<'PYEOF'
import json, sys, os
from datetime import datetime, timezone

def safe_div(a, b):
    return a / b if b != 0 else 0.0

try:
    claude_json_path = sys.argv[1]
    profile = sys.argv[2]
    capture_all = sys.argv[3] == '1'
    quiet = sys.argv[4] == '1'
    cwd = sys.argv[5]
    metrics_dir = sys.argv[6]

    with open(claude_json_path, 'r') as f:
        data = json.load(f)

    projects = data.get('projects', {})
    if not projects:
        if not quiet:
            print('No project data in ~/.claude.json.')
        sys.exit(0)

    if capture_all:
        targets = list(projects.keys())
    else:
        if cwd not in projects:
            if not quiet:
                print(f'No session data for {cwd} in ~/.claude.json.')
                print('Use --all to capture all projects.')
            sys.exit(0)
        targets = [cwd]

    timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    filename_ts = datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')
    count = 0

    for project_path in targets:
        p = projects[project_path]

        cost = p.get('lastCost', 0)
        duration_ms = p.get('lastDuration', 0)
        api_duration_ms = p.get('lastAPIDuration', 0)
        input_tokens = p.get('lastTotalInputTokens', 0)
        output_tokens = p.get('lastTotalOutputTokens', 0)
        cache_creation = p.get('lastTotalCacheCreationInputTokens', 0)
        cache_read = p.get('lastTotalCacheReadInputTokens', 0)
        lines_added = p.get('lastLinesAdded', 0)
        lines_removed = p.get('lastLinesRemoved', 0)
        model_usage = p.get('lastModelUsage', {})

        total_input = cache_read + cache_creation + input_tokens
        cache_hit_rate = round(safe_div(cache_read, total_input), 3)

        snapshot = {
            'profile': profile,
            'timestamp': timestamp,
            'project': project_path,
            'cost_usd': cost,
            'duration_seconds': round(duration_ms / 1000),
            'api_duration_seconds': round(api_duration_ms / 1000),
            'total_input_tokens': input_tokens,
            'total_output_tokens': output_tokens,
            'cache_creation_tokens': cache_creation,
            'cache_read_tokens': cache_read,
            'cache_hit_rate': cache_hit_rate,
            'lines_added': lines_added,
            'lines_removed': lines_removed,
            'model_usage': model_usage,
        }

        # Write snapshot file
        if capture_all:
            proj_name = os.path.basename(project_path.rstrip('/'))
            out_path = os.path.join(metrics_dir, f'{filename_ts}-{proj_name}.json')
        else:
            out_path = os.path.join(metrics_dir, f'{filename_ts}.json')

        with open(out_path, 'w') as f:
            json.dump(snapshot, f, indent=2)
            f.write('\n')

        count += 1

        if not quiet:
            dur_min = duration_ms / 60000
            print(f'Snapshot saved: {os.path.basename(out_path)}')
            print(f'  Profile:    {profile}')
            print(f'  Project:    {project_path}')
            print(f'  Cost:       ${cost:.2f}')
            print(f'  Duration:   {dur_min:.1f}m')
            print(f'  Cache hit:  {cache_hit_rate * 100:.1f}%')
            if count < len(targets):
                print()

    if not quiet and count > 1:
        print(f'\n{count} snapshots saved.')

except Exception as e:
    if len(sys.argv) > 4 and sys.argv[4] != '1':
        print(f'Snapshot failed: {e}')
    sys.exit(0)
PYEOF
}

# Compute session averages from _metrics/sessions/ data.
# Outputs one line per profile: <profile> <sessions> <avg_cost> <avg_duration_s> <avg_cache_hit>
_session_averages() {
	local sessions_dir="$REPO_DIR/_metrics/sessions"
	[ -d "$sessions_dir" ] || return 0

	python3 - "$sessions_dir" <<'PYEOF'
import json, os, sys, shlex

try:
    sessions_dir = sys.argv[1]

    for profile_name in sorted(os.listdir(sessions_dir)):
        profile_dir = os.path.join(sessions_dir, profile_name)
        if not os.path.isdir(profile_dir):
            continue

        costs = []
        durations = []
        cache_hits = []

        for fname in sorted(os.listdir(profile_dir)):
            if not fname.endswith('.json'):
                continue
            fpath = os.path.join(profile_dir, fname)
            try:
                with open(fpath, 'r') as f:
                    snap = json.load(f)
                costs.append(snap.get('cost_usd', 0))
                durations.append(snap.get('duration_seconds', 0))
                cache_hits.append(snap.get('cache_hit_rate', 0))
            except (json.JSONDecodeError, OSError):
                continue

        if costs:
            avg_cost = sum(costs) / len(costs)
            avg_dur = sum(durations) / len(durations)
            avg_cache = sum(cache_hits) / len(cache_hits)
            print(f'{shlex.quote(profile_name)} {len(costs)} {avg_cost:.2f} {avg_dur:.0f} {avg_cache:.3f}')

except Exception:
    pass
PYEOF
}

# ─── Benchmarks ───────────────────────────────────────────────────────────────

# Run a single benchmark task. Called by cmd_benchmark.
# Usage: _benchmark_run_task <task_dir> <profile>
_benchmark_run_task() {
	local task_dir="$1"
	local profile="$2"
	local task_name
	task_name="$(basename "$task_dir")"

	echo "  Running: $task_name"

	# Create temp working directory
	local tmpdir
	tmpdir="$(mktemp -d)"

	# Clean up on exit
	trap "rm -r '$tmpdir' 2>/dev/null || true" RETURN

	# Copy fixture files if present
	if [ -d "$task_dir/fixture" ]; then
		cp -a "$task_dir/fixture/." "$tmpdir/"
	fi

	# Copy expected files if present (for verify.sh to reference)
	if [ -d "$task_dir/expected" ]; then
		cp -a "$task_dir/expected" "$tmpdir/_expected"
	fi

	# Run claude in print mode with JSON output for metrics capture
	local prompt
	prompt="$(cat "$task_dir/prompt.md")"
	local claude_exit=0
	local claude_output_file="$tmpdir/_claude_output.json"

	(cd "$tmpdir" && claude -p \
		--dangerously-skip-permissions \
		--output-format json \
		--max-budget-usd 5 \
		"$prompt" > "$claude_output_file" 2>/dev/null) || claude_exit=$?

	# Run verification
	local passed=false
	local verify_output=""
	if [ -f "$task_dir/verify.sh" ]; then
		verify_output="$("$task_dir/verify.sh" "$tmpdir" 2>&1)" && passed=true || passed=false
	fi

	# Run Tier 3 analyzers (always-on, zero cost)
	local analyzers_dir="$REPO_DIR/benchmarks/analyzers"
	local analyzer_output=""
	if [ -d "$analyzers_dir" ]; then
		# Security smells
		analyzer_output+="$(python3 "$analyzers_dir/security_smells.py" "$tmpdir" 2>/dev/null || true)"$'\n'
		# Naming quality (Python tasks only)
		analyzer_output+="$(python3 "$analyzers_dir/naming_quality.py" "$tmpdir" 2>/dev/null || true)"$'\n'
		# Over-engineering
		analyzer_output+="$(python3 "$analyzers_dir/overengineering.py" "$tmpdir" "$task_dir/task.json" 2>/dev/null || true)"$'\n'
		# Regression check (only for fix-python-bug)
		if [ "$task_name" = "fix-python-bug" ] && [ -d "$task_dir/fixture" ]; then
			analyzer_output+="$(python3 "$analyzers_dir/regression_check.py" "$tmpdir" "$task_dir/fixture" 2>/dev/null || true)"$'\n'
		fi
		# LLM-as-judge (uses subscription via claude -p)
		# Disabled during initial runs to avoid slowdown — enable with BENCHMARK_JUDGE=1
		if [ "${BENCHMARK_JUDGE:-0}" = "1" ] && command -v claude &>/dev/null; then
			analyzer_output+="$(python3 "$analyzers_dir/llm_judge.py" "$tmpdir" "$task_name" 2>/dev/null || true)"$'\n'
		fi
	fi
	verify_output="$verify_output"$'\n'"$analyzer_output"

	# Extract metrics from verify output
	local quality_score
	quality_score="$(echo "$verify_output" | grep -oE 'SCORE:[0-9]+' | tail -1 | cut -d: -f2)"
	[ -z "$quality_score" ] && { [ "$passed" = "true" ] && quality_score=100 || quality_score=0; }

	local files_extra
	files_extra="$(echo "$verify_output" | grep -oE 'FILES_EXTRA:[0-9]+' | cut -d: -f2)"
	[ -z "$files_extra" ] && files_extra=0

	local lines_generated
	lines_generated="$(echo "$verify_output" | grep -oE 'LINES_GENERATED:[0-9]+' | cut -d: -f2)"
	[ -z "$lines_generated" ] && lines_generated=0

	local lint_issues
	lint_issues="$(echo "$verify_output" | grep -oE 'LINT_ISSUES:[0-9]+' | cut -d: -f2)"
	[ -z "$lint_issues" ] && lint_issues=0

	local complexity_avg
	complexity_avg="$(echo "$verify_output" | grep -oE 'COMPLEXITY_AVG:[0-9.]+' | cut -d: -f2)"
	[ -z "$complexity_avg" ] && complexity_avg=0

	local complexity_max
	complexity_max="$(echo "$verify_output" | grep -oE 'COMPLEXITY_MAX:[0-9]+' | cut -d: -f2)"
	[ -z "$complexity_max" ] && complexity_max=0

	local max_func_length
	max_func_length="$(echo "$verify_output" | grep -oE 'MAX_FUNCTION_LENGTH:[0-9]+' | cut -d: -f2)"
	[ -z "$max_func_length" ] && max_func_length=0

	local funcs_over_50
	funcs_over_50="$(echo "$verify_output" | grep -oE 'FUNCTIONS_OVER_50:[0-9]+' | cut -d: -f2)"
	[ -z "$funcs_over_50" ] && funcs_over_50=0

	# Tier 3 analyzer metrics
	local security_smells
	security_smells="$(echo "$verify_output" | grep -oE 'SECURITY_SMELLS:[0-9]+' | cut -d: -f2)"
	[ -z "$security_smells" ] && security_smells=0

	local naming_score
	naming_score="$(echo "$verify_output" | grep -oE 'NAMING_SCORE:[0-9]+' | cut -d: -f2)"
	[ -z "$naming_score" ] && naming_score=100

	local naming_generic
	naming_generic="$(echo "$verify_output" | grep -oE 'NAMING_GENERIC_COUNT:[0-9]+' | cut -d: -f2)"
	[ -z "$naming_generic" ] && naming_generic=0

	local overengineering_score
	overengineering_score="$(echo "$verify_output" | grep -oE 'OVERENGINEERING_SCORE:[0-9]+' | cut -d: -f2)"
	[ -z "$overengineering_score" ] && overengineering_score=100

	local regression_score
	regression_score="$(echo "$verify_output" | grep -oE 'REGRESSION_SCORE:[0-9]+' | cut -d: -f2)"
	[ -z "$regression_score" ] && regression_score=100

	local regression_broken
	regression_broken="$(echo "$verify_output" | grep -oE 'REGRESSION_BROKEN:[0-9]+' | cut -d: -f2)"
	[ -z "$regression_broken" ] && regression_broken=0

	local judge_score
	judge_score="$(echo "$verify_output" | grep -oE 'JUDGE_SCORE:[0-9]+' | cut -d: -f2)"
	[ -z "$judge_score" ] && judge_score=0

	local judge_readability
	judge_readability="$(echo "$verify_output" | grep -oE 'JUDGE_READABILITY:[0-9]+' | cut -d: -f2)"
	[ -z "$judge_readability" ] && judge_readability=0

	local judge_naming
	judge_naming="$(echo "$verify_output" | grep -oE 'JUDGE_NAMING:[0-9]+' | cut -d: -f2)"
	[ -z "$judge_naming" ] && judge_naming=0

	local judge_error_handling
	judge_error_handling="$(echo "$verify_output" | grep -oE 'JUDGE_ERROR_HANDLING:[0-9]+' | cut -d: -f2)"
	[ -z "$judge_error_handling" ] && judge_error_handling=0

	local judge_idiomatic
	judge_idiomatic="$(echo "$verify_output" | grep -oE 'JUDGE_IDIOMATIC:[0-9]+' | cut -d: -f2)"
	[ -z "$judge_idiomatic" ] && judge_idiomatic=0

	local judge_abstraction
	judge_abstraction="$(echo "$verify_output" | grep -oE 'JUDGE_ABSTRACTION:[0-9]+' | cut -d: -f2)"
	[ -z "$judge_abstraction" ] && judge_abstraction=0

	# Extract metrics from claude JSON output and write result
	local results_dir="$REPO_DIR/_metrics/benchmarks/$profile/$task_name"
	mkdir -p "$results_dir"
	local timestamp
	timestamp="$(date -u +%Y%m%d-%H%M%S)"

	python3 - "$claude_output_file" "$profile" "$task_name" \
		"$results_dir/${timestamp}.json" "$passed" "$quality_score" \
		"$files_extra" "$lines_generated" "$lint_issues" \
		"$complexity_avg" "$complexity_max" "$max_func_length" "$funcs_over_50" \
		"$security_smells" "$naming_score" "$naming_generic" \
		"$overengineering_score" "$regression_score" "$regression_broken" \
		"$judge_score" "$judge_readability" "$judge_naming" \
		"$judge_error_handling" "$judge_idiomatic" "$judge_abstraction" <<'PYEOF'
import json, sys
from datetime import datetime, timezone

def safe_div(a, b):
    return a / b if b != 0 else 0.0

try:
    claude_output_path = sys.argv[1]
    profile = sys.argv[2]
    task_name = sys.argv[3]
    out_path = sys.argv[4]
    passed = sys.argv[5] == 'true'
    quality_score = int(sys.argv[6])
    files_extra = int(sys.argv[7])
    lines_generated = int(sys.argv[8])
    lint_issues = int(sys.argv[9])
    complexity_avg = float(sys.argv[10])
    complexity_max = int(sys.argv[11])
    max_func_length = int(sys.argv[12])
    funcs_over_50 = int(sys.argv[13])
    security_smells = int(sys.argv[14])
    naming_score = int(sys.argv[15])
    naming_generic = int(sys.argv[16])
    overengineering_score = int(sys.argv[17])
    regression_score = int(sys.argv[18])
    regression_broken = int(sys.argv[19])
    judge_score = int(sys.argv[20])
    judge_readability = int(sys.argv[21])
    judge_naming = int(sys.argv[22])
    judge_error_handling = int(sys.argv[23])
    judge_idiomatic = int(sys.argv[24])
    judge_abstraction = int(sys.argv[25])

    cost = 0
    duration = 0
    input_tokens = 0
    output_tokens = 0
    cache_read = 0
    cache_creation = 0
    model = "unknown"

    try:
        with open(claude_output_path, 'r') as f:
            data = json.load(f)
        cost = data.get('total_cost_usd', 0)
        duration = round(data.get('duration_ms', 0) / 1000)
        usage = data.get('usage', {})
        input_tokens = usage.get('input_tokens', 0)
        output_tokens = usage.get('output_tokens', 0)
        cache_read = usage.get('cache_read_input_tokens', 0)
        cache_creation = usage.get('cache_creation_input_tokens', 0)
        model_usage = data.get('modelUsage', {})
        if model_usage:
            model = list(model_usage.keys())[0]
    except Exception:
        pass

    total_in = cache_read + cache_creation + input_tokens
    cache_efficiency = round(safe_div(cache_read, total_in), 3)

    result = {
        'profile': profile,
        'task': task_name,
        'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'passed': passed,
        'score': 1 if passed else 0,
        'quality_score': quality_score,
        'cost_usd': cost,
        'duration_seconds': duration,
        'total_input_tokens': input_tokens,
        'total_output_tokens': output_tokens,
        'output_tokens_raw': output_tokens,
        'cache_read_tokens': cache_read,
        'cache_creation_tokens': cache_creation,
        'cache_efficiency': cache_efficiency,
        'model': model,
        'files_extra': files_extra,
        'lines_generated': lines_generated,
        'lint_issues': lint_issues,
        'complexity_avg': complexity_avg,
        'complexity_max': complexity_max,
        'max_function_length': max_func_length,
        'functions_over_50': funcs_over_50,
        'security_smells': security_smells,
        'naming_score': naming_score,
        'naming_generic_count': naming_generic,
        'overengineering_score': overengineering_score,
        'regression_score': regression_score,
        'regression_broken': regression_broken,
        'judge_score': judge_score,
        'judge_readability': judge_readability,
        'judge_naming': judge_naming,
        'judge_error_handling': judge_error_handling,
        'judge_idiomatic': judge_idiomatic,
        'judge_abstraction': judge_abstraction,
    }

    with open(out_path, 'w') as f:
        json.dump(result, f, indent=2)
        f.write('\n')

except Exception as e:
    try:
        fallback = {
            'profile': sys.argv[2], 'task': sys.argv[3],
            'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            'passed': sys.argv[5] == 'true',
            'score': 1 if sys.argv[5] == 'true' else 0,
            'quality_score': int(sys.argv[6]) if len(sys.argv) > 6 else 0,
            'cost_usd': 0, 'duration_seconds': 0,
            'total_input_tokens': 0, 'total_output_tokens': 0,
            'output_tokens_raw': 0,
            'cache_read_tokens': 0, 'cache_creation_tokens': 0,
            'cache_efficiency': 0, 'model': 'unknown', 'error': str(e),
        }
        with open(sys.argv[4], 'w') as f:
            json.dump(fallback, f, indent=2)
            f.write('\n')
    except Exception:
        pass
PYEOF

	# Print result
	if [ "$passed" = "true" ]; then
		echo "    PASS  $verify_output"
	else
		echo "    FAIL  $verify_output"
		if [ "$claude_exit" -ne 0 ]; then
			echo "    (claude exited with code $claude_exit)"
		fi
	fi
}

# Check for regressions in benchmark results for a profile.
_benchmark_check_regressions() {
	local profile="$1"
	local benchmarks_dir="$REPO_DIR/_metrics/benchmarks/$profile"
	[ -d "$benchmarks_dir" ] || return 0

	python3 - "$benchmarks_dir" <<'PYEOF'
import json, os, sys

try:
    benchmarks_dir = sys.argv[1]

    for task_name in sorted(os.listdir(benchmarks_dir)):
        task_dir = os.path.join(benchmarks_dir, task_name)
        if not os.path.isdir(task_dir):
            continue

        results = []
        for fname in sorted(os.listdir(task_dir)):
            if not fname.endswith('.json'):
                continue
            try:
                with open(os.path.join(task_dir, fname)) as f:
                    results.append(json.load(f))
            except (json.JSONDecodeError, OSError):
                continue

        if len(results) < 2:
            continue

        latest = results[-1]
        previous = results[:-1]

        # Check pass -> fail regression
        prev_passed = any(r.get('passed', False) for r in previous)
        if prev_passed and not latest.get('passed', False):
            print(f'  \u26a0 Regression: "{task_name}" \u2014 was passing, now failing')

        # Check cost increase >10%
        prev_costs = [r.get('cost_usd', 0) for r in previous if r.get('cost_usd', 0) > 0]
        if prev_costs and latest.get('cost_usd', 0) > 0:
            avg_cost = sum(prev_costs) / len(prev_costs)
            curr_cost = latest['cost_usd']
            if avg_cost > 0 and (curr_cost - avg_cost) / avg_cost > 0.10:
                pct = ((curr_cost - avg_cost) / avg_cost) * 100
                print(f'  \u26a0 Cost increase: "{task_name}" \u2014 avg ${avg_cost:.2f} \u2192 ${curr_cost:.2f} (+{pct:.0f}%)')

except Exception:
    pass
PYEOF
}

# Show benchmark results across all profiles (read-only, no execution).
_benchmark_report() {
	local benchmarks_dir="$REPO_DIR/_metrics/benchmarks"
	if [ ! -d "$benchmarks_dir" ]; then
		echo "No benchmark data in _metrics/benchmarks/"
		echo "Run './setup.sh benchmark' to generate results."
		return 0
	fi

	python3 - "$benchmarks_dir" "$REPO_DIR/benchmarks/tasks" <<'PYEOF'
import json, os, sys

try:
    benchmarks_dir = sys.argv[1]
    tasks_dir = sys.argv[2]

    # Discover all task names
    task_names = sorted([
        d for d in os.listdir(tasks_dir)
        if os.path.isfile(os.path.join(tasks_dir, d, 'task.json'))
    ]) if os.path.isdir(tasks_dir) else []

    # Discover all profiles with results
    profiles = sorted([
        d for d in os.listdir(benchmarks_dir)
        if os.path.isdir(os.path.join(benchmarks_dir, d))
    ])

    if not profiles:
        print('No benchmark results found.')
        sys.exit(0)

    def get_latest(profile, task):
        task_dir = os.path.join(benchmarks_dir, profile, task)
        if not os.path.isdir(task_dir):
            return None
        files = sorted([f for f in os.listdir(task_dir) if f.endswith('.json')])
        if not files:
            return None
        try:
            with open(os.path.join(task_dir, files[-1])) as f:
                return json.load(f)
        except Exception:
            return None

    def get_run_count(profile, task):
        task_dir = os.path.join(benchmarks_dir, profile, task)
        if not os.path.isdir(task_dir):
            return 0
        return len([f for f in os.listdir(task_dir) if f.endswith('.json')])

    # Symbols (assigned to vars for Python 3.10 f-string compat)
    dash = '\u2014'
    check = '\u2713'
    cross = '\u2717'

    # Column widths
    task_w = max((len(t) for t in task_names), default=20)
    task_w = max(task_w, 20)
    col_w = max((len(p) for p in profiles), default=12)
    col_w = max(col_w, 12)

    print()
    print('  Benchmark Results (last run per task)')
    print('  ' + '\u2500' * 76)

    # Header row
    header = f'  {"Task":<{task_w}}'
    for p in profiles:
        header += f'  {p:>{col_w}}'
    print(header)

    # Data rows
    totals = {p: {'passed': 0, 'total': 0, 'cost': 0.0} for p in profiles}

    for task in task_names:
        row = f'  {task:<{task_w}}'
        for p in profiles:
            r = get_latest(p, task)
            runs = get_run_count(p, task)
            if r is None:
                row += f'  {dash:>{col_w}}'
            else:
                passed = r.get('passed', False)
                cost = r.get('cost_usd', 0)
                mark = check if passed else cross
                cell = f'{mark} ${cost:.2f}'
                if runs > 1:
                    cell += f' ({runs})'
                row += f'  {cell:>{col_w}}'
                totals[p]['total'] += 1
                if passed:
                    totals[p]['passed'] += 1
                totals[p]['cost'] += cost
        print(row)

    # Summary
    print()
    score_row = f'  {"Score":<{task_w}}'
    cost_row = f'  {"Avg cost":<{task_w}}'
    for p in profiles:
        t = totals[p]
        if t['total'] > 0:
            pct = t['passed'] * 100 // t['total']
            score_cell = f'{t["passed"]}/{t["total"]} ({pct}%)'
            score_row += f'  {score_cell:>{col_w}}'
            avg = t['cost'] / t['total']
            cost_cell = f'${avg:.2f}'
            cost_row += f'  {cost_cell:>{col_w}}'
        else:
            score_row += f'  {dash:>{col_w}}'
            cost_row += f'  {dash:>{col_w}}'
    print(score_row)
    print(cost_row)
    print()

except Exception as e:
    print(f'Report failed: {e}')
PYEOF
}

# Generate HTML dashboard with Chart.js radar charts, cost bars, trend lines, and results table.
_benchmark_html_report() {
	local benchmarks_dir="$REPO_DIR/_metrics/benchmarks"
	local tasks_dir="$REPO_DIR/benchmarks/tasks"
	local out_file="$REPO_DIR/_metrics/dashboard.html"

	if [ ! -d "$benchmarks_dir" ]; then
		echo "No benchmark data in _metrics/benchmarks/"
		return 1
	fi

	mkdir -p "$REPO_DIR/_metrics"

	python3 - "$benchmarks_dir" "$tasks_dir" "$out_file" <<'PYEOF'
import json, os, sys, html

benchmarks_dir = sys.argv[1]
tasks_dir = sys.argv[2]
out_file = sys.argv[3]

COLORS = {
    'blank': {'bg': 'rgba(59, 130, 246, 0.2)', 'border': 'rgb(59, 130, 246)'},
    'main': {'bg': 'rgba(16, 185, 129, 0.2)', 'border': 'rgb(16, 185, 129)'},
    'opinionated': {'bg': 'rgba(245, 158, 11, 0.2)', 'border': 'rgb(245, 158, 11)'},
}
FALLBACK_COLORS = [
    {'bg': 'rgba(139, 92, 246, 0.2)', 'border': 'rgb(139, 92, 246)'},
    {'bg': 'rgba(239, 68, 68, 0.2)', 'border': 'rgb(239, 68, 68)'},
    {'bg': 'rgba(236, 72, 153, 0.2)', 'border': 'rgb(236, 72, 153)'},
]

def get_color(profile, idx):
    if profile in COLORS:
        return COLORS[profile]
    return FALLBACK_COLORS[idx % len(FALLBACK_COLORS)]

try:
    # Discover tasks and profiles
    task_names = sorted([
        d for d in os.listdir(tasks_dir)
        if os.path.isfile(os.path.join(tasks_dir, d, 'task.json'))
    ]) if os.path.isdir(tasks_dir) else []

    profiles = sorted([
        d for d in os.listdir(benchmarks_dir)
        if os.path.isdir(os.path.join(benchmarks_dir, d))
    ])

    # Load all results
    all_results = {}  # {profile: {task: [results]}}
    for p in profiles:
        all_results[p] = {}
        for t in task_names:
            task_dir = os.path.join(benchmarks_dir, p, t)
            if not os.path.isdir(task_dir):
                continue
            results = []
            for fname in sorted(os.listdir(task_dir)):
                if not fname.endswith('.json'):
                    continue
                try:
                    with open(os.path.join(task_dir, fname)) as f:
                        results.append(json.load(f))
                except Exception:
                    continue
            if results:
                all_results[p][t] = results

    # Compute radar data per profile (8 axes, all 0-100, higher = better)
    # Uses min-max scaling: best = 95, worst = 30, equal = 95
    radar_data = {}
    profile_avgs = {}  # {profile: {metric: avg_value}}

    FLOOR = 30  # worst score on radar
    CEIL = 95   # best score on radar

    def minmax_scale(values, invert=False):
        """Scale values to FLOOR-CEIL range. If invert, lower raw = higher score."""
        if not values:
            return []
        mn, mx = min(values), max(values)
        if mn == mx:
            return [CEIL] * len(values)
        scaled = []
        for v in values:
            if invert:
                norm = (mx - v) / (mx - mn)
            else:
                norm = (v - mn) / (mx - mn)
            scaled.append(round(FLOOR + norm * (CEIL - FLOOR), 1))
        return scaled

    # First pass: compute per-profile averages
    for p in profiles:
        tasks_data = all_results.get(p, {})
        if not tasks_data:
            continue
        latest = [runs[-1] for runs in tasks_data.values()]
        total = len(latest)
        profile_avgs[p] = {
            'pass_rate': sum(1 for r in latest if r.get('passed', False)) * 100 / total,
            'quality': sum(r.get('quality_score', 100 if r.get('passed') else 0) for r in latest) / total,
            'cost': sum(r.get('cost_usd', 0) for r in latest) / total,
            'duration': sum(r.get('duration_seconds', 0) for r in latest) / total,
            'tokens': sum(r.get('output_tokens_raw', r.get('total_output_tokens', 0)) for r in latest) / total,
            'cache': sum(r.get('cache_efficiency', 0) for r in latest) * 100 / total,
            'lint': sum(r.get('lint_issues', 0) for r in latest) / total,
            'complexity': sum(r.get('complexity_avg', 0) for r in latest) / total,
            'naming': sum(r.get('naming_score', 100) for r in latest) / total,
            'overeng': sum(r.get('overengineering_score', 100) for r in latest) / total,
            'security': sum(r.get('security_smells', 0) for r in latest) / total,
            'judge': sum(r.get('judge_score', 0) for r in latest) / total,
        }

    active_profiles = [p for p in profiles if p in profile_avgs]

    # Scale each metric across profiles
    metrics_config = [
        ('pass_rate', False),    # higher = better
        ('quality', False),      # higher = better
        ('judge', False),        # higher = better
        ('naming', False),       # higher = better
        ('overeng', False),      # higher = better
        ('security', True),      # lower = better
        ('lint', True),          # lower = better
        ('complexity', True),    # lower = better
        ('tokens', True),        # lower = better
        ('duration', True),      # lower = better
    ]
    radar_labels = ['Pass Rate', 'Quality', 'Judge Score', 'Naming',
                    'Simplicity', 'Security', 'Code Cleanliness', 'Low Complexity',
                    'Token Efficiency', 'Speed']

    for metric, invert in metrics_config:
        raw_values = [profile_avgs[p][metric] for p in active_profiles]
        scaled = minmax_scale(raw_values, invert=invert)
        for i, p in enumerate(active_profiles):
            if p not in radar_data:
                radar_data[p] = {}
            radar_data[p][metric] = scaled[i]

    # Tokens per task per profile (for bar chart — more meaningful than cost for subscription)
    token_data = {}  # {profile: {task: {input, output, cache_creation, cache_read}}}
    for p in profiles:
        token_data[p] = {}
        for t in task_names:
            runs = all_results.get(p, {}).get(t, [])
            if runs:
                r = runs[-1]
                token_data[p][t] = {
                    'input': r.get('total_input_tokens', 0),
                    'output': r.get('output_tokens_raw', r.get('total_output_tokens', 0)),
                    'cache_creation': r.get('cache_creation_tokens', 0),
                    'cache_read': r.get('cache_read_tokens', 0),
                }

    # Trend data (all runs over time)
    trend_data = {}  # {profile: [{timestamp, cost, quality}]}
    has_trends = False
    for p in profiles:
        runs_list = []
        for t, runs in all_results.get(p, {}).items():
            for r in runs:
                runs_list.append(r)
        if len(runs_list) > len(task_names):
            has_trends = True
        runs_list.sort(key=lambda x: x.get('timestamp', ''))
        trend_data[p] = runs_list

    # Build results table data
    table_rows = []
    for p in profiles:
        for t in task_names:
            runs = all_results.get(p, {}).get(t, [])
            if runs:
                r = runs[-1]
                table_rows.append({
                    'profile': p,
                    'task': t,
                    'passed': r.get('passed', False),
                    'quality_score': r.get('quality_score', 100 if r.get('passed') else 0),
                    'cost': r.get('cost_usd', 0),
                    'duration': r.get('duration_seconds', 0),
                    'output_tokens': r.get('output_tokens_raw', r.get('total_output_tokens', 0)),
                    'cache_efficiency': r.get('cache_efficiency', 0),
                    'lint_issues': r.get('lint_issues', 0),
                    'complexity': r.get('complexity_avg', 0),
                    'files_extra': r.get('files_extra', 0),
                    'lines_generated': r.get('lines_generated', 0),
                })

    # Generate HTML
    radar_datasets_js = []
    metric_keys = [m for m, _ in metrics_config]
    for i, p in enumerate(active_profiles):
        c = get_color(p, i)
        d = radar_data[p]
        vals = [d.get(k, 50) for k in metric_keys]
        radar_datasets_js.append(f"""{{
            label: '{html.escape(p)}',
            data: {json.dumps(vals)},
            backgroundColor: '{c["bg"]}',
            borderColor: '{c["border"]}',
            borderWidth: 2,
            pointBackgroundColor: '{c["border"]}'
        }}""")

    # Output tokens per task (grouped bar — one bar per profile)
    output_token_datasets_js = []
    for i, p in enumerate(profiles):
        c = get_color(p, i)
        vals = [token_data.get(p, {}).get(t, {}).get('output', 0) for t in task_names]
        output_token_datasets_js.append(f"""{{
            label: '{html.escape(p)}',
            data: {json.dumps(vals)},
            backgroundColor: '{c["border"]}',
            borderRadius: 4
        }}""")

    # Total tokens per profile (stacked bar showing composition)
    token_categories = ['Input', 'Output', 'Cache Creation', 'Cache Read']
    token_cat_colors = ['#f87171', '#fbbf24', '#34d399', '#60a5fa']
    token_stacked_datasets = []
    for ci, (cat, cat_key) in enumerate(zip(token_categories, ['input', 'output', 'cache_creation', 'cache_read'])):
        vals = []
        for p in profiles:
            total = sum(td.get(cat_key, 0) for td in token_data.get(p, {}).values())
            vals.append(total)
        token_stacked_datasets.append(f"""{{
            label: '{cat}',
            data: {json.dumps(vals)},
            backgroundColor: '{token_cat_colors[ci]}'
        }}""")

    trend_datasets_js = ""
    if has_trends:
        trend_cost_ds = []
        trend_quality_ds = []
        for i, p in enumerate(profiles):
            c = get_color(p, i)
            runs = trend_data.get(p, [])
            cost_points = json.dumps([{'x': r['timestamp'], 'y': r.get('cost_usd', 0)} for r in runs])
            quality_points = json.dumps([{'x': r['timestamp'], 'y': r.get('quality_score', 0)} for r in runs])
            trend_cost_ds.append(f"""{{
                label: '{html.escape(p)}',
                data: {cost_points},
                borderColor: '{c["border"]}',
                backgroundColor: '{c["bg"]}',
                tension: 0.3, fill: false
            }}""")
            trend_quality_ds.append(f"""{{
                label: '{html.escape(p)}',
                data: {quality_points},
                borderColor: '{c["border"]}',
                backgroundColor: '{c["bg"]}',
                tension: 0.3, fill: false
            }}""")
        trend_datasets_js = f"""
        new Chart(document.getElementById('trendCost'), {{
            type: 'line',
            data: {{ datasets: [{','.join(trend_cost_ds)}] }},
            options: {{
                responsive: true,
                plugins: {{ title: {{ display: true, text: 'Cost Over Time', font: {{ size: 16 }} }} }},
                scales: {{
                    x: {{ type: 'time', time: {{ unit: 'day' }}, title: {{ display: true, text: 'Date' }} }},
                    y: {{ title: {{ display: true, text: 'Cost (USD)' }}, beginAtZero: true }}
                }}
            }}
        }});
        new Chart(document.getElementById('trendQuality'), {{
            type: 'line',
            data: {{ datasets: [{','.join(trend_quality_ds)}] }},
            options: {{
                responsive: true,
                plugins: {{ title: {{ display: true, text: 'Quality Score Over Time', font: {{ size: 16 }} }} }},
                scales: {{
                    x: {{ type: 'time', time: {{ unit: 'day' }}, title: {{ display: true, text: 'Date' }} }},
                    y: {{ title: {{ display: true, text: 'Quality Score' }}, min: 0, max: 100 }}
                }}
            }}
        }});
        """

    table_html = ""
    for row in table_rows:
        c = get_color(row['profile'], profiles.index(row['profile']))
        badge = '<span class="badge pass">PASS</span>' if row['passed'] else '<span class="badge fail">FAIL</span>'
        lint_badge = f'<span class="badge pass">{row["lint_issues"]}</span>' if row['lint_issues'] == 0 else f'<span class="badge fail">{row["lint_issues"]}</span>'
        extra_badge = f'<span class="badge pass">{row["files_extra"]}</span>' if row['files_extra'] == 0 else f'<span class="badge fail">{row["files_extra"]}</span>'
        table_html += f"""<tr>
            <td><span class="dot" style="background:{c['border']}"></span>{html.escape(row['profile'])}</td>
            <td>{html.escape(row['task'])}</td>
            <td>{badge}</td>
            <td>{row['quality_score']}</td>
            <td>${row['cost']:.4f}</td>
            <td>{row['duration']}s</td>
            <td>{row['output_tokens']:,}</td>
            <td>{lint_badge}</td>
            <td>{row['complexity']:.1f}</td>
            <td>{extra_badge}</td>
            <td>{row['lines_generated']}</td>
        </tr>"""

    trend_html = ""
    if has_trends:
        trend_html = """
        <div class="section">
            <h2>Trends</h2>
            <div class="chart-row">
                <div class="chart-container"><canvas id="trendCost"></canvas></div>
                <div class="chart-container"><canvas id="trendQuality"></canvas></div>
            </div>
        </div>"""

    trend_adapter = ""
    if has_trends:
        trend_adapter = '<script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns@3"></script>'

    page = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Claude Personalities — Benchmark Dashboard</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
{trend_adapter}
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #e2e8f0; padding: 2rem; }}
  h1 {{ font-size: 1.8rem; margin-bottom: 0.5rem; color: #f8fafc; }}
  h2 {{ font-size: 1.3rem; margin-bottom: 1rem; color: #94a3b8; }}
  .subtitle {{ color: #64748b; margin-bottom: 2rem; }}
  .section {{ background: #1e293b; border-radius: 12px; padding: 1.5rem; margin-bottom: 1.5rem; }}
  .chart-row {{ display: flex; gap: 1.5rem; flex-wrap: wrap; }}
  .chart-container {{ flex: 1; min-width: 300px; max-width: 600px; }}
  .radar-container {{ flex: 1; min-width: 350px; max-width: 500px; aspect-ratio: 1; }}
  table {{ width: 100%; border-collapse: collapse; }}
  th {{ text-align: left; padding: 0.75rem; color: #94a3b8; border-bottom: 1px solid #334155; font-weight: 500; }}
  td {{ padding: 0.75rem; border-bottom: 1px solid #1e293b; }}
  tr:hover {{ background: #1e293b; }}
  .badge {{ padding: 2px 8px; border-radius: 4px; font-size: 0.8rem; font-weight: 600; }}
  .badge.pass {{ background: #065f46; color: #6ee7b7; }}
  .badge.fail {{ background: #7f1d1d; color: #fca5a5; }}
  .dot {{ display: inline-block; width: 10px; height: 10px; border-radius: 50%; margin-right: 8px; }}
  .generated {{ text-align: center; color: #475569; margin-top: 2rem; font-size: 0.85rem; }}
</style>
</head>
<body>
<h1>Claude Personalities — Benchmark Dashboard</h1>
<p class="subtitle">Generated from _metrics/benchmarks/ &middot; {len(profiles)} profiles &middot; {len(task_names)} tasks</p>

<div class="section">
    <h2>Profile Radar — 6-Axis Comparison</h2>
    <div class="chart-row">
        <div class="radar-container"><canvas id="radar"></canvas></div>
    </div>
</div>

<div class="section">
    <h2>Token Usage</h2>
    <div class="chart-row">
        <div class="chart-container" style="max-width:600px"><canvas id="outputTokenBar"></canvas></div>
        <div class="chart-container" style="max-width:600px"><canvas id="tokenBreakdown"></canvas></div>
    </div>
</div>

{trend_html}

<div class="section">
    <h2>Results Detail</h2>
    <table>
        <thead><tr><th>Profile</th><th>Task</th><th>Status</th><th>Quality</th><th>Cost</th><th>Duration</th><th>Tokens</th><th>Lint</th><th>Complexity</th><th>Extra Files</th><th>Lines</th></tr></thead>
        <tbody>{table_html}</tbody>
    </table>
</div>

<p class="generated">Generated by ./setup.sh benchmark --report --html</p>

<script>
new Chart(document.getElementById('radar'), {{
    type: 'radar',
    data: {{
        labels: {json.dumps(radar_labels)},
        datasets: [{','.join(radar_datasets_js)}]
    }},
    options: {{
        responsive: true,
        maintainAspectRatio: true,
        scales: {{
            r: {{
                min: 20, max: 100,
                ticks: {{ stepSize: 10, color: '#64748b', backdropColor: 'transparent' }},
                grid: {{ color: '#334155' }},
                angleLines: {{ color: '#334155' }},
                pointLabels: {{ color: '#94a3b8', font: {{ size: 13 }} }}
            }}
        }},
        plugins: {{ legend: {{ labels: {{ color: '#e2e8f0' }} }} }}
    }}
}});

new Chart(document.getElementById('outputTokenBar'), {{
    type: 'bar',
    data: {{
        labels: {json.dumps(task_names)},
        datasets: [{','.join(output_token_datasets_js)}]
    }},
    options: {{
        responsive: true,
        plugins: {{
            legend: {{ labels: {{ color: '#e2e8f0' }} }},
            title: {{ display: true, text: 'Output Tokens per Task', font: {{ size: 14 }}, color: '#94a3b8' }}
        }},
        scales: {{
            x: {{ ticks: {{ color: '#94a3b8' }}, grid: {{ color: '#1e293b' }} }},
            y: {{ ticks: {{ color: '#94a3b8' }}, grid: {{ color: '#334155' }}, title: {{ display: true, text: 'Tokens', color: '#94a3b8' }} }}
        }}
    }}
}});
new Chart(document.getElementById('tokenBreakdown'), {{
    type: 'bar',
    data: {{
        labels: {json.dumps(profiles)},
        datasets: [{','.join(token_stacked_datasets)}]
    }},
    options: {{
        responsive: true,
        plugins: {{
            legend: {{ labels: {{ color: '#e2e8f0' }} }},
            title: {{ display: true, text: 'Total Token Breakdown by Profile', font: {{ size: 14 }}, color: '#94a3b8' }}
        }},
        scales: {{
            x: {{ stacked: true, ticks: {{ color: '#94a3b8' }}, grid: {{ color: '#1e293b' }} }},
            y: {{ stacked: true, ticks: {{ color: '#94a3b8' }}, grid: {{ color: '#334155' }}, title: {{ display: true, text: 'Tokens', color: '#94a3b8' }} }}
        }}
    }}
}});

{trend_datasets_js}
</script>
</body>
</html>"""

    with open(out_file, 'w') as f:
        f.write(page)

    print(f'Dashboard written to {out_file}')

except Exception as e:
    print(f'Dashboard generation failed: {e}')
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

	# Open in default browser
	if [ -f "$out_file" ]; then
		open "$out_file" 2>/dev/null || xdg-open "$out_file" 2>/dev/null || echo "Open $out_file in your browser."
	fi
}

# Main benchmark command.
# Usage: cmd_benchmark [--task <name>] [--report] [--html]
cmd_benchmark() {
	local mode="run"
	local single_task=""
	local html_flag=0

	while [ $# -gt 0 ]; do
		case "$1" in
			--task)
				single_task="${2:-}"
				if [ -z "$single_task" ]; then
					echo "usage: ./setup.sh benchmark --task <name>"
					return 1
				fi
				shift 2
				;;
			--report)
				mode="report"
				shift
				;;
			--html)
				html_flag=1
				shift
				;;
			*)
				shift
				;;
		esac
	done

	if [ "$html_flag" -eq 1 ] && [ "$mode" != "report" ]; then
		echo "usage: ./setup.sh benchmark --report --html"
		echo "--html requires --report"
		return 1
	fi

	if [ "$mode" = "report" ]; then
		if [ "$html_flag" -eq 1 ]; then
			_benchmark_html_report
		else
			_benchmark_report
		fi
		return
	fi

	local profile
	profile="$(git -C "$REPO_DIR" branch --show-current 2>/dev/null || echo "unknown")"
	local tasks_dir="$REPO_DIR/benchmarks/tasks"

	if [ ! -d "$tasks_dir" ]; then
		echo "No benchmark tasks found in benchmarks/tasks/"
		return 1
	fi

	# Check claude CLI is available
	if ! command -v claude &>/dev/null; then
		echo "claude CLI not found. Install Claude Code first."
		return 1
	fi

	# Warn if running inside a Claude Code session (nested claude -p may hang)
	if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] || [ -n "${CLAUDE_SESSION_ID:-}" ]; then
		echo ""
		echo "  ⚠ Running inside a Claude Code session."
		echo "  Benchmarks use 'claude -p' which may conflict with the active session."
		echo "  For reliable results, run from a regular terminal:"
		echo "    ./setup.sh benchmark"
		echo ""
	fi

	echo ""
	echo "Benchmark Runner — Profile: $profile"
	printf '═%.0s' {1..60}; echo ""

	local task_count=0
	local pass_count=0

	for task_dir in "$tasks_dir"/*/; do
		[ -f "$task_dir/task.json" ] || continue
		local name
		name="$(basename "$task_dir")"

		# Filter to single task if specified
		if [ -n "$single_task" ] && [ "$name" != "$single_task" ]; then
			continue
		fi

		_benchmark_run_task "$task_dir" "$profile"
		task_count=$((task_count + 1))

		# Check if passed from the result file
		local latest
		latest="$(ls -t "$REPO_DIR/_metrics/benchmarks/$profile/$name/"*.json 2>/dev/null | head -1)"
		if [ -n "$latest" ]; then
			local did_pass
			did_pass="$(python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        print(json.load(f).get('passed', False))
except Exception:
    print('False')
" "$latest")"
			[ "$did_pass" = "True" ] && pass_count=$((pass_count + 1))
		fi
	done

	if [ -n "$single_task" ] && [ "$task_count" -eq 0 ]; then
		echo "Task '$single_task' not found in benchmarks/tasks/"
		return 1
	fi

	echo ""
	printf '─%.0s' {1..60}; echo ""
	echo "  Results: $pass_count/$task_count passed"
	echo ""

	# Regression detection
	_benchmark_check_regressions "$profile"
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
	snapshot)     shift; cmd_snapshot "$@" ;;
	benchmark)    shift; cmd_benchmark "$@" ;;
	profile)      shift; cmd_profile "$@" ;;
	*)            usage ;;
esac
