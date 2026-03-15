# Phase 2: Session Snapshots — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture `~/.claude.json` session metrics after each Claude Code session, attribute them to the active profile, and accumulate cost/latency history in `_metrics/sessions/`.

**Architecture:** A new `cmd_snapshot` bash function reads `~/.claude.json` via python3, extracts `last*` fields for the current project (or all projects), and writes timestamped JSON snapshots to `_metrics/sessions/<profile>/`. The existing `_profile_table()` is extended to append session averages when data exists.

**Tech Stack:** Bash (setup.sh), Python3 (stdlib only — json, subprocess, sys, shlex, datetime, os, pathlib)

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `setup.sh` | Modify | Add `cmd_snapshot` function, `_session_averages` helper, update `_profile_table()`, update `usage()`, update dispatch |

Single-file change — all work happens in `setup.sh`.

---

## Prerequisite

Before starting, verify you're on the `main` branch:

```bash
git branch --show-current  # must be "main"
```

If not on `main`, switch: `git checkout main`.

---

## Chunk 1: Core Snapshot Command

### Task 1: Add `cmd_snapshot` function

**Files:**
- Modify: `setup.sh` (insert after `_profile_compare` function, ~line 1037, before `cmd_profile`)

- [ ] **Step 1: Add `cmd_snapshot` function skeleton and argument parsing**

Insert this function after the `_profile_compare` closing brace (line 1037) and before `cmd_profile` (line 1040):

```bash
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
            # Use project dir name as suffix to distinguish
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
```

- [ ] **Step 2: Verify function parses correctly**

Run:
```bash
bash -n setup.sh
```
Expected: exit 0, no syntax errors.

- [ ] **Step 3: Commit skeleton**

```bash
git add setup.sh
git commit -m "Add cmd_snapshot function for session metric capture"
```

---

### Task 2: Wire up dispatch and usage text

**Files:**
- Modify: `setup.sh` — `usage()` function (~line 60) and dispatch `case` block (~line 1086)

- [ ] **Step 1: Add snapshot to usage text**

In the `usage()` function, after the "Profiling:" section (after line 73), add:

```
Metrics:
  snapshot                         Capture current session metrics for active profile
  snapshot --all                   Capture metrics for all projects
```

- [ ] **Step 2: Add snapshot to dispatch**

In the `case` dispatch block (before the `*)` catch-all), add:

```bash
snapshot)     shift; cmd_snapshot "$@" ;;
```

- [ ] **Step 3: Verify syntax and help output**

Run:
```bash
bash -n setup.sh && ./setup.sh 2>&1 | grep -A2 "Metrics:"
```
Expected: Shows the "Metrics:" section with snapshot commands.

- [ ] **Step 4: Test snapshot with real data**

Run:
```bash
./setup.sh snapshot
```
Expected: Prints snapshot summary with Profile, Project, Cost, Duration, Cache hit. Creates file in `_metrics/sessions/main/` (assuming you're on the `main` branch).

Then verify:
```bash
ls _metrics/sessions/main/ && cat _metrics/sessions/main/*.json | python3 -m json.tool | head -20
```
Expected: Valid JSON with all fields from the spec.

- [ ] **Step 5: Test --quiet flag**

Run:
```bash
./setup.sh snapshot --quiet && echo "exit: $?"
```
Expected: No stdout, exit 0. A new snapshot file appears in `_metrics/sessions/main/`.

- [ ] **Step 6: Test missing project path**

Run from a directory with no session data:
```bash
(cd /tmp && "$REPO_DIR/setup.sh" snapshot)
```
Where `$REPO_DIR` is the path to this repo. If running manually, substitute the actual path.
Expected: "No session data for /tmp in ~/.claude.json. Use --all to capture all projects."

- [ ] **Step 7: Commit**

```bash
git add setup.sh
git commit -m "Wire snapshot command into dispatch and usage text"
```

---

## Chunk 2: Session Averages in Profile Table

### Task 3: Add `_session_averages` helper function

**Files:**
- Modify: `setup.sh` — insert after `cmd_snapshot`, before `cmd_profile`

- [ ] **Step 1: Add `_session_averages` helper**

This function reads all snapshots in `_metrics/sessions/` and outputs per-profile averages. Insert after `cmd_snapshot`:

```bash
# Compute session averages from _metrics/sessions/ data.
# Outputs one line per profile: <profile> <sessions> <avg_cost> <avg_duration_s> <avg_cache_hit>
_session_averages() {
	local sessions_dir="$REPO_DIR/_metrics/sessions"
	[ -d "$sessions_dir" ] || return 0

	python3 - "$sessions_dir" <<'PYEOF'
import json, os, sys, shlex

try:
    sessions_dir = sys.argv[1]
    profiles = {}

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
```

- [ ] **Step 2: Verify syntax**

Run:
```bash
bash -n setup.sh
```
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add setup.sh
git commit -m "Add _session_averages helper for reading snapshot data"
```

---

### Task 4: Append session averages to `_profile_table()`

**Files:**
- Modify: `setup.sh` — `_profile_table()` function, after the capability matrix section (~line 811)

- [ ] **Step 1: Add session averages section to `_profile_table()`**

At the end of `_profile_table()`, just before the final `echo ""` (line 813), add:

```bash
	# Session averages (if snapshot data exists)
	local session_data
	session_data="$(_session_averages)"
	if [ -n "$session_data" ]; then
		echo "  Session Averages (from _metrics/sessions/)"
		printf '  '; printf '─%.0s' {1..76}; echo ""
		printf "  %-14s %8s  %9s  %12s  %12s\n" \
			"Profile" "Sessions" "Avg Cost" "Avg Duration" "Avg Cache%"

		while IFS= read -r line; do
			[ -z "$line" ] && continue
			read -r prof sessions avg_cost avg_dur avg_cache <<< "$line"
			# Remove quotes from profile name
			prof="$(echo "$prof" | tr -d "'")"
			# Format duration as Xm Ys
			local dur_min=$(( ${avg_dur%.*} / 60 ))
			local dur_sec=$(( ${avg_dur%.*} % 60 ))
			local dur_fmt="${dur_min}m ${dur_sec}s"
			# Format cache hit as percentage
			local cache_pct
			cache_pct="$(python3 -c "print(f'{float(${avg_cache}) * 100:.1f}%')")"

			printf "  %-14s %8s  %9s  %12s  %12s\n" \
				"$prof" "$sessions" "\$${avg_cost}" "$dur_fmt" "$cache_pct"
		done <<< "$session_data"

		echo ""
	fi
```

- [ ] **Step 2: Verify syntax**

Run:
```bash
bash -n setup.sh
```
Expected: exit 0.

- [ ] **Step 3: Test profile table with session data**

Run:
```bash
./setup.sh profile 2>&1 | tail -20
```
Expected: The standard profile comparison table, followed by a "Session Averages" section showing the snapshot(s) we captured earlier.

- [ ] **Step 4: Test profile table without session data**

Run (after clearing metrics):
```bash
mv _metrics _metrics_bak && ./setup.sh profile 2>&1 | tail -10 && mv _metrics_bak _metrics
```
Expected: No "Session Averages" section when `_metrics/sessions/` is absent.

- [ ] **Step 5: Commit**

```bash
git add setup.sh
git commit -m "Show session averages in profile comparison table"
```

---

## Chunk 3: Documentation and Cleanup

### Task 5: Add SessionEnd hook documentation

**Files:**
- Modify: `setup.sh` — `usage()` function

- [ ] **Step 1: Add hook hint to usage text**

After the "Metrics:" section in `usage()`, add a blank line and then:

```
  Tip: Auto-capture with a SessionEnd hook in claude/settings.json:
    "hooks": { "SessionEnd": [{ "type": "command",
      "command": "~/git/claude_personalities/setup.sh snapshot --quiet" }] }
```

- [ ] **Step 2: Verify**

Run:
```bash
bash -n setup.sh && ./setup.sh 2>&1 | grep -A4 "Tip:"
```
Expected: Shows the SessionEnd hook documentation.

- [ ] **Step 3: Commit**

```bash
git add setup.sh
git commit -m "Document SessionEnd hook for auto-capture in usage text"
```

---

### Task 6: Clean up test snapshots and final verification

- [ ] **Step 1: Remove test snapshot data**

```bash
rm -r _metrics/sessions/
```

- [ ] **Step 2: Run full end-to-end verification**

Run each command and verify output:

```bash
# 1. Usage text shows snapshot commands
./setup.sh 2>&1 | grep -A3 "Metrics:"

# 2. Snapshot captures correctly
./setup.sh snapshot
ls _metrics/sessions/main/
cat _metrics/sessions/main/*.json | python3 -m json.tool

# 3. --quiet flag works
./setup.sh snapshot --quiet
echo "Files after quiet: $(ls _metrics/sessions/main/ | wc -l)"

# 4. Profile table shows session averages
./setup.sh profile 2>&1 | grep -A5 "Session Averages"

# 5. Syntax check
bash -n setup.sh
```

- [ ] **Step 3: Clean up test data again**

```bash
rm -r _metrics/sessions/
```

- [ ] **Step 4: Final commit (if any remaining changes)**

```bash
git diff --quiet setup.sh || { git add setup.sh && git commit -m "Phase 2 cleanup"; }
```

---

## Propagation

After Phase 2 is complete on `main`, propagate `setup.sh` to `blank` and `opinionated` branches:

```bash
# Copy setup.sh to other branches
for branch in blank opinionated; do
    git show main:setup.sh | git blob-inject "$branch" setup.sh  # conceptual — use cherry-pick or manual copy
done
```

**Note:** This step is manual — done between sessions using `git checkout` + copy, or cherry-pick. Do NOT run `./setup.sh use` during the current session.

---

## Summary of Changes

| What | Where | Lines (est.) |
|------|-------|-------------|
| `cmd_snapshot()` | setup.sh, after profiler section | ~100 |
| `_session_averages()` | setup.sh, after cmd_snapshot | ~40 |
| Session averages display | `_profile_table()` in setup.sh | ~25 |
| Usage text update | `usage()` in setup.sh | ~6 |
| Dispatch entry | `case` block in setup.sh | ~1 |
| **Total** | | **~172 lines added** |
