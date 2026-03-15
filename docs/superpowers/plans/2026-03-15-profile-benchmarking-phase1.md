# Profile Benchmarking Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the static profile profiler — `./setup.sh profile` with table, detail, and compare modes — that measures and compares Claude Code personality profiles across token overhead, plugin counts, capabilities, and cost estimates.

**Architecture:** All profiler logic lives in `setup.sh` as new bash functions. JSON parsing uses inline `python3 -c "import json; ..."` (python3 ships with macOS, no pip packages needed). Data files (capabilities.json, plugin-metadata.json, pricing, etc.) are JSON at the repo root or in `benchmarks/`. Profile manifests (profile.json) are per-branch. Shared files (capabilities.json, plugin-metadata.json, benchmarks/) are always read from the `main` branch via `git show main:<file>` to avoid drift across branches.

**Tech Stack:** bash, git (`git show` for cross-branch reads), python3 (JSON parsing only)

**Spec:** `docs/superpowers/specs/2026-03-15-profile-benchmarking-design.md`

**Branch:** Work on `main`. Currently on `opinionated` — the implementer must commit or stash any uncommitted changes, then switch to main via `git checkout main` (NOT `./setup.sh use main` which disrupts symlinks).

**Important constraints:**
- Do NOT modify files in `claude/` or `home/` — those are profile content
- Do NOT run `./setup.sh use` — it changes symlinks and disrupts the active session
- All new commands are additions to `setup.sh`, not modifications to existing commands
- Use tabs for indentation (matching existing setup.sh style)
- The script uses `set -euo pipefail` — all Python calls MUST exit 0 even on error (wrap in try/except)
- Pass data to Python via `sys.argv`, not bash string interpolation (prevents injection)
- Use `shlex.quote()` for all string values output from Python to prevent shell injection

**Security note:** The `_profile_gather` function outputs shell variable assignments that are `eval`'d. All string values MUST be escaped with `shlex.quote()` to prevent injection from malicious profile.json content.

---

## Task 1: Create JSON Data Files

**Files:**
- Create: `capabilities.json`
- Create: `plugin-metadata.json`
- Create: `benchmarks/base-overhead.json`
- Create: `benchmarks/pricing.json`
- Create: `profile.json`
- Modify: `.gitignore`

- [ ] **Step 1: Switch to main branch**

```bash
cd ~/git/claude_personalities
git add -A && git stash
git checkout main
```

Verify: `git branch --show-current` shows `main`.

Note: `git stash pop` after all work is complete if you need to return to the previous state. The stash contains any uncommitted changes from the opinionated branch (likely just `home/.claude.json`).

- [ ] **Step 2: Create capabilities.json**

Create `capabilities.json` at repo root. This is the shared capability vocabulary — maps capability names to the plugins/skills that provide them. Content is specified exactly in the spec (Section "Capability Registry").

```json
{
	"frontend-design": {
		"description": "Create and refine web UI components and pages",
		"provided_by": [
			{ "plugin": "frontend-design" },
			{ "plugin": "impeccable" }
		],
		"benchmark_task": "create-react-component"
	},
	"tdd-workflow": {
		"description": "Red-green-refactor test-driven development",
		"provided_by": [
			{ "plugin": "superpowers", "skill": "test-driven-development" }
		],
		"benchmark_task": "write-unit-tests"
	},
	"code-review": {
		"description": "Automated code review for pull requests",
		"provided_by": [
			{ "plugin": "code-review" }
		],
		"benchmark_task": "review-code-diff"
	},
	"browser-testing": {
		"description": "Headless browser automation for QA and testing",
		"provided_by": [
			{ "plugin": "playwright" }
		],
		"benchmark_task": null
	},
	"api-docs-lookup": {
		"description": "Up-to-date library documentation lookup",
		"provided_by": [
			{ "plugin": "context7" }
		],
		"benchmark_task": null
	},
	"typescript-intelligence": {
		"description": "TypeScript/JavaScript language server for code intelligence",
		"provided_by": [
			{ "plugin": "typescript-lsp" }
		],
		"benchmark_task": null
	},
	"design-polish": {
		"description": "Design quality review, polish, and normalization",
		"provided_by": [
			{ "plugin": "impeccable" }
		],
		"benchmark_task": null
	},
	"autonomous-loops": {
		"description": "Continuous iterative development loops",
		"provided_by": [
			{ "plugin": "ralph-loop" }
		],
		"benchmark_task": null
	}
}
```

Verify: `python3 -c "import json; json.load(open('capabilities.json')); print('valid')"` prints `valid`

- [ ] **Step 3: Create plugin-metadata.json**

Create `plugin-metadata.json` at repo root. Contains manually maintained skill counts, MCP tool counts, and listing token estimates for each known plugin.

```json
{
	"superpowers": {
		"marketplace": "claude-plugins-official",
		"skills": 22,
		"mcp_tools": 0,
		"listing_tokens": 880,
		"description": "Core skills: TDD, debugging, collaboration patterns"
	},
	"impeccable": {
		"marketplace": "impeccable",
		"skills": 18,
		"mcp_tools": 0,
		"listing_tokens": 720,
		"description": "Design vocabulary: polish, distill, audit, bolder, quieter"
	},
	"playwright": {
		"marketplace": "claude-plugins-official",
		"skills": 0,
		"mcp_tools": 25,
		"listing_tokens": 500,
		"description": "Browser automation and testing"
	},
	"context7": {
		"marketplace": "claude-plugins-official",
		"skills": 0,
		"mcp_tools": 2,
		"listing_tokens": 40,
		"description": "Library documentation lookup"
	},
	"code-review": {
		"marketplace": "claude-plugins-official",
		"skills": 1,
		"mcp_tools": 0,
		"listing_tokens": 40,
		"description": "PR code review"
	},
	"ralph-loop": {
		"marketplace": "claude-plugins-official",
		"skills": 3,
		"mcp_tools": 0,
		"listing_tokens": 120,
		"description": "Autonomous iterative loops"
	},
	"frontend-design": {
		"marketplace": "claude-plugins-official",
		"skills": 1,
		"mcp_tools": 0,
		"listing_tokens": 40,
		"description": "Frontend design skill"
	},
	"typescript-lsp": {
		"marketplace": "claude-plugins-official",
		"skills": 0,
		"mcp_tools": 0,
		"lsp_servers": 1,
		"listing_tokens": 20,
		"description": "TypeScript language server"
	}
}
```

Verify: `python3 -c "import json; json.load(open('plugin-metadata.json')); print('valid')"` prints `valid`

- [ ] **Step 4: Create benchmarks directory and data files**

```bash
mkdir -p benchmarks
```

Create `benchmarks/base-overhead.json`:

```json
{
	"claude_code_version": "2.1.76",
	"source": "https://github.com/Piebald-AI/claude-code-system-prompts",
	"last_updated": "2026-03-15",
	"base_tokens": {
		"system_prompt_fragments": 3000,
		"tool_descriptions": 8500,
		"misc_overhead": 1500,
		"total": 13000
	},
	"notes": "Tokens Claude Code injects regardless of profile configuration. Profile overhead is additive. Update when Claude Code releases a new version with significant prompt changes."
}
```

Create `benchmarks/pricing.json`:

```json
{
	"last_updated": "2026-03-15",
	"source": "https://platform.claude.com/docs/en/about-claude/pricing",
	"models": {
		"opus-4.6": {
			"cache_read_per_mtok": 0.50,
			"cache_miss_per_mtok": 5.00,
			"output_per_mtok": 25.00
		},
		"sonnet-4.6": {
			"cache_read_per_mtok": 0.30,
			"cache_miss_per_mtok": 3.00,
			"output_per_mtok": 15.00
		},
		"haiku-4.5": {
			"cache_read_per_mtok": 0.10,
			"cache_miss_per_mtok": 1.00,
			"output_per_mtok": 5.00
		}
	},
	"default_model": "opus-4.6"
}
```

Verify: Both files parse as valid JSON.

- [ ] **Step 5: Create profile.json for main branch**

Create `profile.json` at repo root:

```json
{
	"name": "main",
	"description": "Full-featured daily driver with design, testing, and development skills",
	"author": "",
	"category": "full-stack",
	"tags": ["design", "testing", "browser-automation", "code-review", "tdd"],
	"capabilities": [
		"frontend-design",
		"tdd-workflow",
		"code-review",
		"browser-testing",
		"api-docs-lookup",
		"typescript-intelligence",
		"design-polish",
		"autonomous-loops"
	]
}
```

- [ ] **Step 6: Add _metrics/ to .gitignore**

Append `_metrics/` to the existing `.gitignore` file. The file currently contains:

```
_backups/
.DS_Store
*.swp
*.swo
*~
```

Add `_metrics/` as a new line at the end.

- [ ] **Step 7: Commit data files**

```bash
git add capabilities.json plugin-metadata.json benchmarks/ profile.json .gitignore
git commit -m "Add profiler data files and profile manifest for main"
```

---

## Task 2: Write Profiler Core in setup.sh

**Files:**
- Modify: `setup.sh` (add all profiler functions after existing commands, before dispatch section)

This task adds ALL profiler functions to setup.sh: data gathering, display (table/detail/compare), dispatch, and usage text update.

**Key safety patterns used throughout:**
- Python receives data via `sys.argv` (never via bash string interpolation into Python source)
- Python uses `shlex.quote()` for all string values it outputs
- Python is wrapped in try/except and always exits 0
- `eval` only processes the sanitized output

- [ ] **Step 1: Add all profiler functions to setup.sh**

Insert the entire profiler section between the `cmd_pin_version` function and the `# ─── Dispatch` section. The code below is the complete profiler implementation:

```bash
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
	printf '  ─%.0s' {1..76}; echo ""

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
		printf '  ─%.0s' {1..76}; echo ""

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

	printf '  ─%.0s' {1..76}; echo ""
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
	IFS=',' read -ra caps_a <<< "$a_caps"
	IFS=',' read -ra caps_b <<< "$b_caps"

	for cap in "${caps_a[@]}"; do
		[ -z "$cap" ] && continue
		if ! echo ",$b_caps," | grep -q ",$cap,"; then
			only_a="${only_a:+$only_a, }$cap"
		fi
	done
	for cap in "${caps_b[@]}"; do
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
```

- [ ] **Step 2: Update the usage() function**

Replace the existing `usage()` function body to add the Profiling section:

```bash
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
```

- [ ] **Step 3: Update the case dispatch**

In the `case "${1:-}" in` block at the bottom of setup.sh, add the `profile` case. The updated dispatch block should be:

```bash
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
```

Note: The `profile` case uses `shift` then passes `"$@"` so that `cmd_profile` receives the remaining arguments.

- [ ] **Step 4: Commit all setup.sh changes**

```bash
git add setup.sh
git commit -m "Add profile command with table, detail, and compare modes"
```

---

## Task 3: Verify All Modes Work

**Files:** None created — this is verification only.

- [ ] **Step 1: Test default table mode**

```bash
cd ~/git/claude_personalities
./setup.sh profile
```

Expected: Table with 3 rows (blank, main, opinionated), capability matrix below. Verify:
- blank shows 0 plugins, 0 skills, category may show "unknown" if no profile.json on blank yet (that's correct — Task 4 adds it)
- main shows 8 plugins, non-zero skills, "full-stack" category
- Capability matrix shows ✓/— per profile

- [ ] **Step 2: Test detail mode**

```bash
./setup.sh profile --detail main
```

Expected: Token breakdown with bar chart, cost estimate, plugin inventory, user skills list, capabilities list. Verify:
- Token total is reasonable (should be ~4,000-6,000)
- Cost estimate shows dollar amounts
- All 8 plugins listed with skill/tool counts

```bash
./setup.sh profile --detail blank
```

Expected: Minimal profile — 0 plugins, low token count. Category may show "unknown" (no profile.json yet).

- [ ] **Step 3: Test compare mode**

```bash
./setup.sh profile --compare main blank
```

Expected: Side-by-side with deltas. Token delta should be positive (main > blank). Capabilities diff should show all capabilities only in main.

- [ ] **Step 4: Test error handling**

```bash
./setup.sh profile --detail
# Expected: "usage: ./setup.sh profile --detail <branch>"

./setup.sh profile --compare main
# Expected: "usage: ./setup.sh profile --compare <branch-a> <branch-b>"

./setup.sh profile --detail nonexistent
# Expected: "Branch 'nonexistent' not found."
```

- [ ] **Step 5: Test usage text**

```bash
./setup.sh
```

Expected: Usage text now includes the "Profiling:" section with `profile` commands.

- [ ] **Step 6: Fix any issues found and commit**

If any issues were found during verification, fix them and commit:

```bash
git add setup.sh
git commit -m "Fix profiler issues found during verification"
```

Only commit if there are actual changes. Skip if everything worked.

---

## Task 4: Add profile.json to Other Branches

**Files:**
- Create: `profile.json` on `blank` branch
- Create: `profile.json` on `opinionated` branch
- Propagate shared files (capabilities.json, plugin-metadata.json, benchmarks/) to both branches
- Propagate setup.sh changes to both branches

**Important:** This task requires switching branches. The symlinks in `~/.claude/` point into this repo's `claude/` directory — when you `git checkout blank`, the files in `claude/` change, which changes what the symlinks resolve to. This is temporary and will be restored when you return to the original branch. Do NOT use `./setup.sh use` — just raw `git checkout`.

- [ ] **Step 1: Ensure main is clean**

```bash
cd ~/git/claude_personalities
git status
```

All changes from Tasks 1-3 should be committed. If not, commit them first.

- [ ] **Step 2: Add profile.json and shared files to blank branch**

```bash
git checkout blank
```

Create `profile.json`:

```json
{
	"name": "blank",
	"description": "Clean slate — machine environment only, no plugins, no preferences",
	"author": "",
	"category": "minimal",
	"tags": ["minimal", "clean", "baseline"],
	"capabilities": []
}
```

Copy shared infrastructure and setup.sh from main:

```bash
git checkout main -- capabilities.json plugin-metadata.json benchmarks/ .gitignore setup.sh
```

Commit:

```bash
git add profile.json capabilities.json plugin-metadata.json benchmarks/ .gitignore setup.sh
git commit -m "Add profile manifest and shared profiler infrastructure"
```

- [ ] **Step 3: Add profile.json and shared files to opinionated branch**

```bash
git checkout opinionated
```

Create `profile.json`:

```json
{
	"name": "opinionated",
	"description": "Bleeding-edge developer setup with strong defaults and guardrails",
	"author": "",
	"category": "full-stack",
	"tags": ["opinionated", "bleeding-edge", "guardrails", "design", "testing"],
	"capabilities": [
		"frontend-design",
		"tdd-workflow",
		"code-review",
		"browser-testing",
		"api-docs-lookup",
		"typescript-intelligence",
		"design-polish",
		"autonomous-loops"
	]
}
```

Copy shared infrastructure and setup.sh from main:

```bash
git checkout main -- capabilities.json plugin-metadata.json benchmarks/ .gitignore setup.sh
```

Commit:

```bash
git add profile.json capabilities.json plugin-metadata.json benchmarks/ .gitignore setup.sh
git commit -m "Add profile manifest and shared profiler infrastructure"
```

- [ ] **Step 4: Return to main branch**

```bash
git checkout main
```

Verify: `git branch --show-current` shows `main`.

- [ ] **Step 5: Final verification — cross-branch profiling**

```bash
./setup.sh profile
```

Expected: All three profiles now show correct categories and capabilities:
- blank: "minimal" category, 0 capabilities, 0 plugins
- main: "full-stack" category, 8 capabilities, 8 plugins
- opinionated: "full-stack" category, 8 capabilities, 8 plugins

```bash
./setup.sh profile --compare main blank
```

Expected: Clear delta showing main's overhead vs blank's minimal footprint.

```bash
./setup.sh profile --detail opinionated
```

Expected: Full breakdown matching main (since opinionated currently has same profile content as main).
