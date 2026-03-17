# Hybrid Profile + Full Benchmark Matrix Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the hybrid daily-driver profile, validate it with a 75-run pilot, extend tooling for judge score aggregation and 53-task dashboard, then produce execution scripts for the full 795-run expansion.

**Architecture:** Three workstreams — (1) profile creation on a new `hybrid` git branch, (2) tooling upgrades to `aggregate-results.py` and `setup.sh`'s `_benchmark_html_report`, (3) benchmark execution handoff scripts for terminal-based runs.

**Tech Stack:** Bash (setup.sh), Python 3 (aggregation, analyzers), Chart.js 4.4.7 (dashboard HTML), `claude -p` CLI for benchmark runs.

**Spec:** `docs/superpowers/specs/2026-03-17-hybrid-profile-and-full-matrix-design.md`

**Parallelism:** Tasks 1, 2, 5, 6, 7 can be executed in parallel. Task 3 depends on Task 1. Task 4 depends on Task 2. Task 8 depends on all prior tasks.

---

## Task 1: Create Hybrid Branch and Profile Files

**Files:**
- Create: `claude/CLAUDE.md` (on `hybrid` branch)
- Create: `claude/settings.json` (on `hybrid` branch)
- Create: `claude/MEMORY.md` (on `hybrid` branch)

This task creates the `hybrid` git branch from `main`, replaces `claude/CLAUDE.md` with the ~78-line hybrid personality, replaces `claude/settings.json` with 4-plugin lean config, and creates an empty MEMORY.md.

**Important:** This modifies git branches. The work must be done via raw git commands, NOT `./setup.sh use`, since we're inside an active Claude Code session.

- [ ] **Step 1: Create the hybrid branch from main**

```bash
git branch hybrid main
```

- [ ] **Step 2: Write the hybrid CLAUDE.md**

Use `git show main:claude/CLAUDE.md` as the base. Write the new file to a temp location, then commit it onto the hybrid branch using `git checkout hybrid -- path` workflow.

The hybrid CLAUDE.md has three sections:

**Section 1 — Machine Environment** (lines 1-38 from main, identical):
```markdown
# User-Level CLAUDE.md — Anonymous

## Machine Environment

- **OS:** macOS
- **Shell:** zsh with oh-my-zsh (`~/.zshrc`)
- **Editor:** Zed
- **Repos:** `~/git/`

## Node.js (nvm)

This machine uses nvm. Before running any npm/node/npx commands, activate nvm first:

\`\`\`bash
source ~/.nvm/nvm.sh && nvm use
\`\`\`

If a project has `.nvmrc`, `nvm use` picks it up automatically. Otherwise default is Node 22.

## Rust (rustup)

Rust is installed via rustup at `~/.cargo/bin`. The cargo/rustc binaries are not on the default PATH in non-interactive shells. When running Rust tooling:

\`\`\`bash
source "$HOME/.cargo/env"
\`\`\`

## Python (pyenv)

pyenv is installed but may not have Python versions configured yet. Check with:

\`\`\`bash
export PATH="$HOME/.pyenv/bin:$HOME/.pyenv/shims:$PATH"
eval "$(pyenv init -)"
pyenv versions
\`\`\`

If no versions are installed, prompt me before installing one.
```

**Section 2 — Code Standards** (content from variant-hybrid's Code Standards section; copy only the section content below, not variant-hybrid's heading structure which differs):
```markdown
## Code Standards — Hard Limits

These are non-negotiable. If code violates any of these, refactor before committing.

- **Functions:** Maximum 20 lines. Decompose into smaller, named helpers with clear single responsibilities.
- **Cyclomatic complexity:** Maximum 5 per function. Extract conditions into named predicates. Replace nested chains with dispatch tables or early returns.
- **Cognitive complexity:** Maximum 8 per function. Reduce nesting by extracting inner blocks. Flatten control flow with guard clauses.
- **Conciseness:** Prefer concise solutions. Don't decompose trivial problems that are clear as a single function.
- **No unnecessary abstractions.** No wrapper functions, adapter patterns, or helper functions that are called only once unless they improve readability.
- **No magic numbers.** Every numeric literal (except 0, 1, -1) must be a named constant.
- **No commented-out code.** Delete it.
```

**Section 3 — Workflow** (cherry-picked from main):
```markdown
## Global Preferences

- **Indentation:** Tabs (defer to project config if it specifies otherwise)
- **Package manager:** npm
- **Commit style:** Brief imperative sentences ("Add login page", "Fix null check in parser")
- **After code changes:** Auto-run the project's test suite to verify nothing broke
- **Communication style:** Explain reasoning and rationale, don't just show the code
- **Execution options:** When a skill offers execution choices (e.g. subagent-driven vs. parallel session), always pick the most cost-effective option without asking. Prefer subagent-driven development in the current session over spawning separate sessions.
- **Claude usage:** Use Claude subscription (Claude Code) for development work. Reserve API usage for when subscription-based tools are not practical (e.g., embedded in apps, custom integrations, production services).

## When to Ask vs. Proceed

If uncertain about intent, scope, or the right approach — ask before acting. For destructive or hard-to-reverse actions (deleting files, force-pushing, dropping data, modifying CI/CD), always confirm first regardless of confidence.

## Git

- **No Co-Authored-By trailers.** Do not add `Co-Authored-By` lines to commit messages. This includes any AI attribution trailers.
- **Worktrees:** All worktrees live under `.worktrees/` inside the repo root. One worktree per task. Cleanup after merge: `git worktree remove`, `git worktree prune`, `git branch -d`.
- **Plans and docs:** Keep all agent-facing docs, plans, and checklists in the project's `.claude/` directory.
- **GitHub:** Use `git` directly for push/pull (not `gh` CLI — causes HTTP 400 on this machine). PRs via `gh pr create`.

## Things to Never Do

- Never use the system Node at `/usr/local/bin/node`
- Never commit `.env` files, API keys, or secrets
- Never push to main/master without asking
- Never install global npm packages without asking
```

Write the complete file by concatenating all three sections. Then commit onto the hybrid branch:

```bash
# Write to temp, switch to hybrid, replace, commit, switch back
git stash --include-untracked
git checkout hybrid
# (write claude/CLAUDE.md with the content above)
# (write claude/settings.json — see Step 3)
# (write claude/MEMORY.md — see Step 4)
git add claude/CLAUDE.md claude/settings.json claude/MEMORY.md
git commit -m "Create hybrid profile: lean daily-driver with data-proven constraints"
git checkout main
git stash pop
```

- [ ] **Step 3: Write the hybrid settings.json**

Write this exact content to `claude/settings.json` on the hybrid branch:

```json
{
	"cleanupPeriodDays": 99999,
	"permissions": {
		"allow": [
			"Bash(npx:*)",
			"Bash(npm:*)",
			"Bash(node:*)",
			"Bash(python3:*)",
			"Bash(pip3:*)",
			"Bash(pip:*)",
			"Bash(source:*)",
			"Bash(git:*)",
			"Bash(gh:*)",
			"Bash(claude:*)",
			"Bash(ls:*)",
			"Bash(cp:*)",
			"Bash(rm:*)",
			"Bash(mkdir:*)",
			"Bash(wc:*)",
			"Bash(head:*)",
			"Bash(tail:*)",
			"Bash(cat:*)",
			"Bash(tee:*)",
			"Bash(grep:*)",
			"WebSearch"
		],
		"deny": [
			"Read(~/.ssh/**)",
			"Read(~/.aws/**)",
			"Read(~/.gnupg/**)",
			"Read(~/.git-credentials)",
			"Read(~/Library/Keychains/**)",
			"Bash(rm -rf *)",
			"Bash(rm -fr *)",
			"Bash(sudo *)",
			"Bash(git push --force*)",
			"Bash(git reset --hard*)"
		],
		"defaultMode": "acceptEdits"
	},
	"enabledPlugins": {
		"context7@claude-plugins-official": true,
		"superpowers@claude-plugins-official": true,
		"code-review@claude-plugins-official": true,
		"typescript-lsp@claude-plugins-official": true
	},
	"effortLevel": "high",
	"showThinkingSummaries": true,
	"attribution": {
		"commit": "",
		"pr": ""
	}
}
```

- [ ] **Step 4: Write empty MEMORY.md**

```markdown
# Claude Memory
```

- [ ] **Step 5: Sync benchmarks/ and setup.sh from main onto hybrid branch**

```bash
git checkout hybrid
git checkout main -- benchmarks/ setup.sh
git add benchmarks/ setup.sh
git commit -m "Sync benchmark suite and setup.sh from main"
git checkout main
```

- [ ] **Step 6: Verify the hybrid branch**

```bash
git show hybrid:claude/CLAUDE.md | wc -l
# Expected: ~78 lines

git show hybrid:claude/settings.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['enabledPlugins']), 'plugins'); print(len(d['permissions']['deny']), 'deny rules')"
# Expected: 4 plugins, 10 deny rules

git log hybrid --oneline -3
# Expected: 2 commits (profile creation + benchmark sync)
```

- [ ] **Step 7: Commit — profile creation complete**

No additional commit needed — Steps 2-5 already committed on the hybrid branch.

---

## Task 2: Extend aggregate-results.py with Judge Score Metrics

**Files:**
- Modify: `benchmarks/aggregate-results.py:22-26` (KEY_METRICS list)
- Test: manual validation with existing result data

The aggregation script currently tracks 9 metrics. The dashboard upgrades require judge scores to be aggregated too.

- [ ] **Step 1: Add judge score fields to KEY_METRICS**

In `benchmarks/aggregate-results.py`, extend the KEY_METRICS list at line 22-26:

```python
KEY_METRICS = [
	'cost_usd', 'duration_seconds', 'cognitive_complexity_max',
	'max_function_length', 'complexity_max', 'maintainability_index',
	'personality_compliance', 'lines_generated', 'total_output_tokens',
	'judge_score', 'judge_readability', 'judge_naming',
	'judge_error_handling', 'judge_idiomatic', 'judge_abstraction',
	'function_count', 'type_annotation_coverage', 'docstring_coverage',
	'error_handling_density', 'security_smells', 'naming_score',
	'duplicate_score', 'halstead_volume',
]
```

This adds 14 metrics: 6 judge scores + 8 analyzer metrics that were previously missing from aggregation. The script already handles missing values gracefully (line 58: `if r.get(metric) is not None`), so runs without judge data will simply skip those fields.

- [ ] **Step 2: Run aggregation to verify no errors**

```bash
export PATH="$HOME/.pyenv/bin:$HOME/.pyenv/shims:$PATH" && eval "$(pyenv init -)"
python3 benchmarks/aggregate-results.py _metrics | python3 -c "import json,sys; d=json.load(sys.stdin); profiles=list(d.keys()); print(f'{len(profiles)} profiles'); [print(f'  {p}: {len(d[p])} tasks') for p in profiles]"
```

Expected: Lists all profiles with task counts. No errors.

- [ ] **Step 3: Commit**

```bash
git add benchmarks/aggregate-results.py
git commit -m "Extend aggregation with judge scores and additional analyzer metrics"
```

---

## Task 3: Sync Benchmark Suite to Non-Main Branches

**Files:**
- Modify: `benchmarks/` and `setup.sh` on branches: blank, opinionated, hybrid

The benchmark runner reads tasks from `benchmarks/tasks/` on the current branch. All branches must have the same 53-task suite and the latest setup.sh for runs to work.

- [ ] **Step 1: Stash working changes once**

```bash
git stash --include-untracked
```

- [ ] **Step 2: Sync to all three branches**

```bash
for branch in blank opinionated variant-limits-amplified; do
    git checkout "$branch"
    git checkout main -- benchmarks/ setup.sh
    git add benchmarks/ setup.sh
    git commit -m "Sync benchmark suite and setup.sh from main"
done
git checkout main
```

- [ ] **Step 3: Restore working changes**

```bash
git stash pop
```

- [ ] **Step 4: Verify all branches have the same task count**

```bash
for branch in main blank opinionated hybrid variant-limits-amplified; do
  count=$(git ls-tree -d --name-only "$branch:benchmarks/tasks" | wc -l)
  echo "$branch: $count tasks"
done
```

Expected: All branches show 53 tasks.

- [ ] **Step 5: Commit — sync complete**

No additional commit needed — each branch was committed in its own step.

---

## Task 4: Upgrade Dashboard Report Generator for 5 Profiles + 53 Tasks

**Files:**
- Modify: `setup.sh:1895-2485` (`_benchmark_html_report` function)

This is the largest task. The auto-generated dashboard needs to support the hybrid profile, task grouping by source, judge score radar, statistical significance indicators, profile recommendations, and a diminishing returns curve.

- [ ] **Step 1: Add hybrid to the color palette**

In `setup.sh`, inside `_benchmark_html_report` (the embedded Python heredoc starting at line 1907), find the COLORS dict (~line 1914-1928). Add the hybrid color:

The COLORS dict uses `{'bg': 'rgba(...)', 'border': 'rgb(...)'}` format, and `get_color(profile, idx)` returns a dict. Add hybrid and variant-limits-amplified as named entries.

Current (`setup.sh:1914-1923`):
```python
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
```

Change to:
```python
COLORS = {
    'blank': {'bg': 'rgba(59, 130, 246, 0.2)', 'border': 'rgb(59, 130, 246)'},
    'main': {'bg': 'rgba(16, 185, 129, 0.2)', 'border': 'rgb(16, 185, 129)'},
    'opinionated': {'bg': 'rgba(245, 158, 11, 0.2)', 'border': 'rgb(245, 158, 11)'},
    'hybrid': {'bg': 'rgba(236, 72, 153, 0.2)', 'border': 'rgb(236, 72, 153)'},
    'variant-limits-amplified': {'bg': 'rgba(139, 92, 246, 0.2)', 'border': 'rgb(139, 92, 246)'},
}
FALLBACK_COLORS = [
    {'bg': 'rgba(239, 68, 68, 0.2)', 'border': 'rgb(239, 68, 68)'},
    {'bg': 'rgba(6, 182, 212, 0.2)', 'border': 'rgb(6, 182, 212)'},
    {'bg': 'rgba(132, 204, 22, 0.2)', 'border': 'rgb(132, 204, 22)'},
]
```

This ensures hybrid always gets pink and variant-limits-amplified always gets purple.

- [ ] **Step 2: Add task source grouping**

After the discovery phase (~line 1930-1960) where tasks are collected, add a task-to-source mapping function:

```python
def task_source(task_name):
    if task_name.startswith('he-'):
        return 'HumanEval'
    elif task_name.startswith('mbpp-'):
        return 'MBPP'
    elif task_name.startswith('ex-'):
        return 'Exercism'
    elif task_name.startswith('ce-'):
        return 'ClassEval'
    elif task_name.startswith('rf-'):
        return 'Aider'
    else:
        return 'Hand-written'

SOURCE_ORDER = ['HumanEval', 'MBPP', 'Exercism', 'ClassEval', 'Aider', 'Hand-written']
tasks_by_source = {}
for t in all_tasks:
    src = task_source(t)
    tasks_by_source.setdefault(src, []).append(t)
```

- [ ] **Step 3: Add judge score radar chart**

After the existing radar data computation (~line 1962-2041), add a second radar dataset for judge scores. This only renders if judge data exists:

```python
JUDGE_METRICS = ['judge_readability', 'judge_naming', 'judge_error_handling',
                 'judge_idiomatic', 'judge_abstraction', 'judge_score']
JUDGE_LABELS = ['Readability', 'Naming', 'Error Handling', 'Idiomatic', 'Abstraction', 'Overall']

judge_datasets = []
has_judge = False
for i, profile in enumerate(profiles):
    values = []
    for m in JUDGE_METRICS:
        scores = [r.get(m) for r in profile_results[profile] if r.get(m) is not None]
        values.append(round(sum(scores) / len(scores), 1) if scores else 0)
    if any(v > 0 for v in values):
        has_judge = True
    c = get_color(profile, i)
    judge_datasets.append({
        'label': profile,
        'data': values,
        'borderColor': c['border'],
        'backgroundColor': c['bg'],
    })
```

Then in the HTML template, add a conditional judge radar chart after the existing radar:

```javascript
if (hasJudge) {
    new Chart(document.getElementById('judgeRadar'), {
        type: 'radar',
        data: { labels: judgeLabels, datasets: judgeDatasets },
        options: { scales: { r: { min: 0, max: 9, ticks: { stepSize: 1 } } } }
    });
}
```

- [ ] **Step 4: Add statistical significance indicators**

In the heatmap table generation (~line 2262-2285), modify cell rendering to bold-border cells where IQRs don't overlap between profiles:

```python
def iqrs_overlap(results_a, results_b, metric):
    """Check if two profiles' IQRs overlap for a given metric."""
    vals_a = sorted([r.get(metric, 0) for r in results_a if r.get(metric) is not None])
    vals_b = sorted([r.get(metric, 0) for r in results_b if r.get(metric) is not None])
    if len(vals_a) < 2 or len(vals_b) < 2:
        return True  # can't determine, assume overlap
    q1_a = vals_a[len(vals_a)//4] if len(vals_a) >= 4 else vals_a[0]
    q3_a = vals_a[3*len(vals_a)//4] if len(vals_a) >= 4 else vals_a[-1]
    q1_b = vals_b[len(vals_b)//4] if len(vals_b) >= 4 else vals_b[0]
    q3_b = vals_b[3*len(vals_b)//4] if len(vals_b) >= 4 else vals_b[-1]
    return q3_a >= q1_b and q3_b >= q1_a
```

Add a `*` suffix to cells where the best profile's IQR doesn't overlap with the worst profile's IQR for that metric.

- [ ] **Step 5: Add profile recommendation cards**

After the heatmap section, add HTML for recommendation cards. Compute in Python:

```python
# Group tasks by complexity band
COMPLEXITY_BANDS = {
    'Trivial': [t for t in all_tasks if t.startswith('he-')],
    'Moderate': [t for t in all_tasks if t.startswith(('mbpp-', 'ce-'))],
    'Complex': [t for t in all_tasks if t.startswith(('ex-', 'rf-'))],
}

recommendations = {}
for band, tasks in COMPLEXITY_BANDS.items():
    best_cost = None
    best_quality = None
    for profile in profiles:
        costs = [r['cost_usd'] for r in profile_results[profile]
                 if r['task'] in tasks and r.get('cost_usd')]
        qualities = [r.get('cognitive_complexity_max', 100) for r in profile_results[profile]
                     if r['task'] in tasks and r.get('cognitive_complexity_max') is not None]
        avg_cost = sum(costs) / len(costs) if costs else 999
        avg_quality = sum(qualities) / len(qualities) if qualities else 999
        if best_cost is None or avg_cost < best_cost[1]:
            best_cost = (profile, avg_cost)
        if best_quality is None or avg_quality < best_quality[1]:
            best_quality = (profile, avg_quality)
    recommendations[band] = {'cheapest': best_cost, 'best_quality': best_quality}
```

Render as cards in the HTML template with band name, cheapest profile, best-quality profile.

- [ ] **Step 6: Add diminishing returns scatter**

After the Pareto chart section (~line 2287-2302), add a new scatter chart. X-axis: CLAUDE.md line count, Y-axis: composite quality score (inverse of avg cognitive_complexity_max across all tasks).

Compute CLAUDE.md line counts dynamically rather than hardcoding (values drift as profiles are edited):

```python
import subprocess

def get_prompt_size(profile):
    """Get CLAUDE.md line count for a profile from git."""
    try:
        out = subprocess.check_output(
            ['git', 'show', f'{profile}:claude/CLAUDE.md'],
            stderr=subprocess.DEVNULL, text=True
        )
        return len(out.strip().splitlines())
    except subprocess.CalledProcessError:
        return 100  # fallback

diminishing_data = []
for profile in profiles:
    prompt_lines = get_prompt_size(profile)
    qualities = [r.get('cognitive_complexity_max', 0) for r in profile_results[profile]
                 if r.get('cognitive_complexity_max') is not None]
    avg_quality = 100 - (sum(qualities) / len(qualities)) if qualities else 0
    diminishing_data.append({
        'x': prompt_lines,
        'y': round(avg_quality, 1),
        'label': profile
    })
```

Render as Chart.js scatter with point labels.

- [ ] **Step 7: Add task-grouped collapsible sections for detail tables**

In the results table section (~line 2185-2203), wrap tasks by source group using HTML `<details><summary>` elements:

```python
results_html = ''
for source in SOURCE_ORDER:
    tasks_in_source = tasks_by_source.get(source, [])
    if not tasks_in_source:
        continue
    results_html += f'<details open><summary class="text-lg font-semibold text-slate-200 cursor-pointer py-2">{source} ({len(tasks_in_source)} tasks)</summary>'
    results_html += '<table class="w-full text-sm text-slate-300 mb-4"><thead>...</thead><tbody>'
    for task in sorted(tasks_in_source):
        for profile in profiles:
            # ... existing row rendering logic
            pass
    results_html += '</tbody></table></details>'
```

- [ ] **Step 8: Add task-type differentiation analysis**

After the recommendation cards, add a grouped bar chart showing average quality differential (cognitive_complexity_max) per task source group per profile. This answers "do profiles differentiate more on algorithmic vs. architectural vs. refactoring tasks?"

```python
# Compute per-source-group average cognitive_complexity_max for each profile
task_type_data = {}  # {source: {profile: avg_cc}}
for source in SOURCE_ORDER:
    task_type_data[source] = {}
    tasks_in_source = tasks_by_source.get(source, [])
    for profile in profiles:
        cc_values = [
            r.get('cognitive_complexity_max', 0)
            for r in profile_results[profile]
            if r.get('task') in tasks_in_source
            and r.get('cognitive_complexity_max') is not None
        ]
        task_type_data[source][profile] = (
            round(sum(cc_values) / len(cc_values), 1) if cc_values else None
        )
```

Render as a Chart.js grouped bar chart with source groups on x-axis and one bar per profile. Lower is better (less complexity).

- [ ] **Step 9: Test dashboard generation with existing data**

```bash
./setup.sh benchmark --report --html
open _metrics/dashboard.html
```

Expected: Dashboard opens with all discovered profiles (blank, main, opinionated, variant-limits-amplified, variant-minimalism). New sections (judge radar, recommendations, diminishing returns) should appear but may have sparse data until full runs complete.

- [ ] **Step 10: Commit**

```bash
git add setup.sh
git commit -m "Upgrade dashboard: 5 profiles, task grouping, judge radar, recommendations"
```

---

## Task 5: Create Pilot Execution Script

**Files:**
- Create: `benchmarks/run-pilot.sh`

A self-contained script that runs the Phase 1 pilot (5 profiles x 5 tasks x 3 reps) from a regular terminal.

- [ ] **Step 1: Write the pilot script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Phase 1 Pilot: 5 profiles x 5 tasks x 3 reps = 75 runs
# Run from repo root, outside of Claude Code session.
# Usage: ./benchmarks/run-pilot.sh
#
# Note: Some profiles already have 1-3 runs for these tasks.
# This script runs 3 fresh reps unconditionally — extra data improves
# statistical confidence. The aggregation script uses all available runs.

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

PROFILES=(blank main opinionated hybrid variant-limits-amplified)
TASKS=(he-000-has-close-elements mbpp-011-remove-occ ex-bowling ce-000-regex-utils rf-001-command-output-hash)
REPS=3

TOTAL=$((${#PROFILES[@]} * ${#TASKS[@]} * REPS))
RUN=0
ERRORS=0

echo "=== Pilot Benchmark: ${#PROFILES[@]} profiles x ${#TASKS[@]} tasks x $REPS reps = $TOTAL runs ==="
echo ""

for profile in "${PROFILES[@]}"; do
    echo "--- Switching to profile: $profile ---"
    ./setup.sh use "$profile"

    for task in "${TASKS[@]}"; do
        for rep in $(seq 1 $REPS); do
            RUN=$((RUN + 1))
            echo "[$RUN/$TOTAL] $profile / $task (rep $rep)"
            if ! ./setup.sh benchmark --task "$task"; then
                ERRORS=$((ERRORS + 1))
                echo "  WARNING: Run failed"
            fi
        done
    done
done

# Return to main
echo "--- Returning to main profile ---"
./setup.sh use main

echo ""
echo "=== Pilot Complete: $RUN runs, $ERRORS errors ==="
echo "Run './setup.sh benchmark --report --html' to generate the dashboard."
```

- [ ] **Step 2: Make executable**

```bash
chmod +x benchmarks/run-pilot.sh
```

- [ ] **Step 3: Commit**

```bash
git add benchmarks/run-pilot.sh
git commit -m "Add pilot benchmark execution script (75 runs)"
```

---

## Task 6: Create Full Expansion Execution Script

**Files:**
- Create: `benchmarks/run-full-expansion.sh`

Same structure as pilot but all 53 tasks with LLM judge enabled.

- [ ] **Step 1: Write the full expansion script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Phase 2 Full Expansion: 5 profiles x 53 tasks x 3 reps = 795 runs
# Run from repo root, outside of Claude Code session.
# Usage: ./benchmarks/run-full-expansion.sh
#
# Cost estimate: $150-400 (judge enabled)
# Duration: 6-8 hours unattended

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

export BENCHMARK_JUDGE=1

PROFILES=(blank main opinionated hybrid variant-limits-amplified)
REPS=3

# Discover all tasks
TASKS=()
for task_dir in benchmarks/tasks/*/; do
    TASKS+=("$(basename "$task_dir")")
done

TOTAL=$((${#PROFILES[@]} * ${#TASKS[@]} * REPS))
RUN=0
ERRORS=0
COST_FILE=$(mktemp)
echo "0" > "$COST_FILE"

echo "=== Full Expansion: ${#PROFILES[@]} profiles x ${#TASKS[@]} tasks x $REPS reps = $TOTAL runs ==="
echo "LLM Judge: ENABLED"
echo ""

for profile in "${PROFILES[@]}"; do
    echo "--- Switching to profile: $profile ---"
    ./setup.sh use "$profile"

    for task in "${TASKS[@]}"; do
        for rep in $(seq 1 $REPS); do
            RUN=$((RUN + 1))
            echo "[$RUN/$TOTAL] $profile / $task (rep $rep)"
            if ! ./setup.sh benchmark --task "$task"; then
                ERRORS=$((ERRORS + 1))
                echo "  WARNING: Run failed"
            fi
        done
    done

    # Cost checkpoint after each profile
    echo "--- Profile $profile complete ($RUN/$TOTAL runs, $ERRORS errors) ---"
done

# Return to main
echo "--- Returning to main profile ---"
./setup.sh use main

echo ""
echo "=== Full Expansion Complete: $RUN runs, $ERRORS errors ==="
echo "Run './setup.sh benchmark --report --html' to generate the dashboard."
```

- [ ] **Step 2: Make executable**

```bash
chmod +x benchmarks/run-full-expansion.sh
```

- [ ] **Step 3: Commit**

```bash
git add benchmarks/run-full-expansion.sh
git commit -m "Add full expansion benchmark script (795 runs with judge)"
```

---

## Task 7: Create Pilot Analysis Script

**Files:**
- Create: `benchmarks/analyze-pilot.sh`

After the pilot completes, this script checks the exit criteria (hybrid within 20% of variant-limits-amplified on quality, within 15% of blank on cost).

- [ ] **Step 1: Write the analysis script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Analyze pilot results and check hybrid exit criteria.
# Usage: ./benchmarks/analyze-pilot.sh

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

export PATH="$HOME/.pyenv/bin:$HOME/.pyenv/shims:$PATH"
eval "$(pyenv init -)"

echo "=== Pilot Analysis ==="
echo ""

# Aggregate results
python3 benchmarks/aggregate-results.py _metrics > /tmp/pilot-aggregate.json

# Check exit criteria
python3 - <<'PYEOF'
import json

with open('/tmp/pilot-aggregate.json') as f:
    data = json.load(f)

# Exit criterion 1: hybrid cognitive_complexity_max within 20% of variant-limits-amplified on ex-bowling
hybrid_cc = data.get('hybrid', {}).get('ex-bowling', {}).get('metrics', {}).get('cognitive_complexity_max', {}).get('median')
vla_cc = data.get('variant-limits-amplified', {}).get('ex-bowling', {}).get('metrics', {}).get('cognitive_complexity_max', {}).get('median')

if hybrid_cc is not None and vla_cc is not None:
    pct = abs(hybrid_cc - vla_cc) / max(vla_cc, 0.01) * 100
    status = "PASS" if pct <= 20 else "FAIL"
    print(f"Criterion 1: Hybrid cognitive_complexity_max on ex-bowling")
    print(f"  Hybrid: {hybrid_cc}, variant-limits-amplified: {vla_cc}, diff: {pct:.1f}%")
    print(f"  Status: {status} (threshold: within 20%)")
else:
    print(f"Criterion 1: MISSING DATA (hybrid={hybrid_cc}, vla={vla_cc})")

print()

# Exit criterion 2: hybrid cost within 15% of blank's median across 5 tasks
pilot_tasks = ['he-000-has-close-elements', 'mbpp-011-remove-occ', 'ex-bowling',
               'ce-000-regex-utils', 'rf-001-command-output-hash']

hybrid_costs = []
blank_costs = []
for task in pilot_tasks:
    h = data.get('hybrid', {}).get(task, {}).get('metrics', {}).get('cost_usd', {}).get('median')
    b = data.get('blank', {}).get(task, {}).get('metrics', {}).get('cost_usd', {}).get('median')
    if h is not None:
        hybrid_costs.append(h)
    if b is not None:
        blank_costs.append(b)

if hybrid_costs and blank_costs:
    avg_hybrid = sum(hybrid_costs) / len(hybrid_costs)
    avg_blank = sum(blank_costs) / len(blank_costs)
    pct = (avg_hybrid - avg_blank) / max(avg_blank, 0.01) * 100
    status = "PASS" if pct <= 15 else "FAIL"
    print(f"Criterion 2: Hybrid cost vs blank across {len(pilot_tasks)} tasks")
    print(f"  Hybrid avg: ${avg_hybrid:.3f}, Blank avg: ${avg_blank:.3f}, diff: {pct:.1f}%")
    print(f"  Status: {status} (threshold: within 15%)")
else:
    print(f"Criterion 2: MISSING DATA (hybrid={len(hybrid_costs)} tasks, blank={len(blank_costs)} tasks)")

print()

# Summary table
print("=== Per-Profile Summary ===")
print(f"{'Profile':<30} {'Tasks':>5} {'Avg Cost':>10} {'Avg CC Max':>12}")
for profile in sorted(data.keys()):
    costs = []
    cc_maxes = []
    for task in pilot_tasks:
        c = data[profile].get(task, {}).get('metrics', {}).get('cost_usd', {}).get('median')
        cc = data[profile].get(task, {}).get('metrics', {}).get('cognitive_complexity_max', {}).get('median')
        if c is not None:
            costs.append(c)
        if cc is not None:
            cc_maxes.append(cc)
    avg_c = f"${sum(costs)/len(costs):.3f}" if costs else "n/a"
    avg_cc = f"{sum(cc_maxes)/len(cc_maxes):.1f}" if cc_maxes else "n/a"
    print(f"{profile:<30} {len(costs):>5} {avg_c:>10} {avg_cc:>12}")
PYEOF
```

- [ ] **Step 2: Make executable**

```bash
chmod +x benchmarks/analyze-pilot.sh
```

- [ ] **Step 3: Commit**

```bash
git add benchmarks/analyze-pilot.sh
git commit -m "Add pilot analysis script with exit criteria checking"
```

---

## Task 8: Sync All Changes to Non-Main Branches (Final)

**Files:**
- Modify: `benchmarks/` and `setup.sh` on branches: blank, opinionated, hybrid, variant-limits-amplified

After Tasks 2-7 are complete on main, sync the updated tooling to all benchmark branches one final time.

- [ ] **Step 1: Stash, sync all branches, restore**

```bash
git stash --include-untracked
for branch in blank opinionated hybrid variant-limits-amplified; do
    git checkout "$branch"
    git checkout main -- benchmarks/ setup.sh
    git add benchmarks/ setup.sh
    git commit -m "Sync benchmark tooling from main (pre-execution)"
done
git checkout main
git stash pop
```

- [ ] **Step 2: Verify sync**

```bash
for branch in main blank opinionated hybrid variant-limits-amplified; do
    hash=$(git show "$branch:setup.sh" | md5)
    echo "$branch: setup.sh=$hash"
done
```

Expected: All branches show the same md5 hash for setup.sh.

- [ ] **Step 3: Commit — ready for benchmark execution**

No additional commit needed. Print execution instructions:

```
Pilot execution (from regular terminal, NOT Claude Code):
  cd ~/git/claude_personalities
  ./benchmarks/run-pilot.sh

After pilot completes:
  ./benchmarks/analyze-pilot.sh

If pilot passes, full expansion:
  ./benchmarks/run-full-expansion.sh

After full expansion:
  ./setup.sh benchmark --report --html
  open _metrics/dashboard.html
```
