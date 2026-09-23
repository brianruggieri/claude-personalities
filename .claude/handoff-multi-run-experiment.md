# Handoff: Multi-Run Benchmark Experiment

## Your Mission

Run the 45-run benchmark experiment (3 profiles x 5 tasks x 3 repetitions), aggregate the results, update the dashboard with statistically grounded data, and regenerate findings.

**Estimated cost:** $10-15
**Estimated time:** 1-2 hours of benchmark runtime (unattended)

---

## Project Context

This repo (`claude_personalities`) implements switchable Claude Code personality profiles via git branches. We've built a benchmark system to measure whether different profiles produce measurably different code quality, cost, and structure.

### The 3 Profiles (git branches)

| Branch | What it is | System prompt size |
|--------|-----------|-------------------|
| `blank` | No personality — just machine env facts. The control group. | ~30 lines |
| `main` | Full daily-driver config — coding preferences, plugins, skills. | ~160 lines |
| `opinionated` | Strict engineering — TDD, complexity thresholds, enforcement hooks. Everything in main plus enforcement layers. | ~250+ lines |

All profiles use the same model (Claude Opus 4.6), same task prompts, same verification scripts. The only independent variable is the personality configuration.

### What's Been Done

A pilot run (n=1 per cell) across 5 tasks showed that:
- **ex-bowling** is the only task with clear profile differentiation (opinionated: max_func_len=19, cognitive_max=11 vs main: 64, 38)
- **3 of 5 tasks** produced identical/near-identical code across profiles (too constrained)
- **blank is 30-45% cheaper** than opinionated but similar quality on constrained tasks

But with n=1, we can't claim anything "consistent" or "significant." This experiment adds the statistical power.

### What's Been Built (last session, 6 commits)

| Commit | What |
|--------|------|
| `353deaf` | Fixed duplicate_blocks analyzer (was reporting 280 duplicates for 278-line files) |
| `64e6054` | Added personality_compliance diagnostic script |
| `1f053d2` | Added multi-run experimental protocol document |
| `431ad56` | Improved dashboard: 3-axis radar, token efficiency chart, Pareto scatter, marginal cost table, n=1 caveats |
| `6b08d8c` | Added consolidated analyzer test suite (16 checks, all pass) |
| `e7a8614` | Added multi-run results aggregation script |

---

## Phase 1: Pre-Experiment Setup

### 1A. Propagate benchmark tasks to other branches

The 53 task directories in `benchmarks/` currently only exist on `main`. The other branches need them so the benchmark runner can find them.

**CRITICAL:** Do NOT run `./setup.sh use <branch>` — that changes symlinks and disrupts the active Claude Code session. Use raw `git checkout` only.

```bash
cd ~/git/claude_personalities

# Propagate to blank
git checkout blank
git checkout main -- benchmarks/
git add benchmarks/
git commit -m "Sync benchmark tasks from main (53 tasks)"

# Propagate to opinionated
git checkout opinionated
git checkout main -- benchmarks/
git add benchmarks/
git commit -m "Sync benchmark tasks from main (53 tasks)"

# Return to main
git checkout main
```

### 1B. Verify the benchmark runner works

```bash
grep -n '_benchmark_run_task\|benchmark)' setup.sh | head -10
```

Expected: See `_benchmark_run_task()` at ~line 1270 and `benchmark)` at ~line 2585.

The runner interface:
```bash
./setup.sh benchmark                           # Run all tasks for current profile
./setup.sh benchmark --task ex-bowling         # Run single task
./setup.sh benchmark --report --html           # Generate dashboard from results
```

### 1C. Verify existing tests pass

```bash
python3 benchmarks/analyzers/test_duplicate_blocks.py
python3 benchmarks/analyzers/test_analyzers.py
```

Expected: 3/3 and 16/16 pass.

---

## Phase 2: Run the Experiment

**IMPORTANT:** The benchmark runner calls `claude -p` for each task. This MUST be run from a **regular terminal** (not inside a Claude Code session) because nested `claude -p` conflicts with an active session.

### The 5 tasks (chosen for diversity)

| Task | Category | Difficulty | Why included |
|------|----------|-----------|-------------|
| `he-000-has-close-elements` | Function completion | Trivial | Baseline — too simple to differentiate |
| `mbpp-011-remove-occ` | Function completion | Basic | Simple but allows some design choice |
| `ex-bowling` | Full implementation | Expert | Complex branching, many design choices — most differentiating |
| `ce-000-regex-utils` | Class implementation | Advanced | Multi-method class, test-locked |
| `rf-001-command-output-hash` | Refactoring | Intermediate | Modify existing code, tightly constrained |

### Run script (45 runs total)

```bash
cd ~/git/claude_personalities

for rep in 1 2 3; do
  echo "=== Repetition $rep ==="
  for profile in blank main opinionated; do
    echo "--- Profile: $profile ---"
    git checkout $profile
    for task in he-000-has-close-elements mbpp-011-remove-occ ex-bowling ce-000-regex-utils rf-001-command-output-hash; do
      echo "Running: $profile / $task (rep $rep)"
      ./setup.sh benchmark --task $task
    done
  done
done
git checkout main
echo "=== All 45 runs complete ==="
```

Results land in `_metrics/benchmarks/<profile>/<task>/<timestamp>.json`. Multiple runs create separate timestamped files — they don't overwrite.

### Result JSON structure (example)

Each run produces a file like `_metrics/benchmarks/opinionated/ex-bowling/20260316-124448.json`:

```json
{
  "profile": "opinionated",
  "task": "ex-bowling",
  "timestamp": "2026-03-16T12:44:48Z",
  "passed": true,
  "score": 1,
  "cost_usd": 0.271,
  "duration_seconds": 32,
  "total_input_tokens": 7,
  "total_output_tokens": 1467,
  "cache_read_tokens": 135428,
  "cache_creation_tokens": 26607,
  "cache_efficiency": 0.836,
  "model": "claude-opus-4-6[1m]",
  "files_extra": 0,
  "lines_generated": 294,
  "lint_issues": 0,
  "complexity_avg": 2.0,
  "complexity_max": 8,
  "max_function_length": 19,
  "functions_over_50": 0,
  "security_smells": 0,
  "naming_score": 95,
  "overengineering_score": 100,
  "regression_score": 100,
  "cognitive_complexity_avg": 0.9,
  "cognitive_complexity_max": 11,
  "halstead_volume": 6089.54,
  "maintainability_index": 19.64,
  "duplicate_blocks": 280,
  "duplicate_score": 0,
  "personality_compliance": 83,
  "personality_violations": 112
}
```

**Note on `duplicate_blocks`:** The pilot run's `duplicate_blocks: 280` was a known bug (now fixed in the analyzer). New runs will produce correct values. The old n=1 results still have the buggy values — they'll be replaced by the new runs.

---

## Phase 3: Aggregate and Analyze

### 3A. Run the aggregation script

```bash
python3 benchmarks/aggregate-results.py _metrics/
```

This reads all JSON files per (profile, task) cell and outputs:
- `n`: number of runs
- `median`: median value for each metric
- `iqr_low` / `iqr_high`: interquartile range bounds

### 3B. Key metrics to analyze

For each (profile, task) cell with n=3:

| Metric | What it measures | Key question |
|--------|-----------------|-------------|
| `cost_usd` | API cost | Is opinionated consistently more expensive? |
| `cognitive_complexity_max` | Nesting-aware complexity | Does opinionated produce simpler code? |
| `max_function_length` | Longest function (lines) | Does opinionated decompose better? |
| `complexity_max` | Cyclomatic complexity | Correlated with cognitive — keep as validation |
| `maintainability_index` | Composite (Halstead + CC + LOC, 0-100) | Overall code quality signal |
| `lines_generated` | Total non-blank, non-comment lines | Does profile affect code size? |
| `total_output_tokens` | Raw token output | Token efficiency proxy |

### 3C. Statistical analysis criteria

From the protocol (`.claude/context-multi-run-protocol.md`):

- **Report median + IQR** (not mean/stdev — too few observations for normality)
- **Wilcoxon signed-rank test** (paired by task) to compare profiles
- **Claims using "consistently"** require p < 0.05
- **Claims about "differences"** require non-overlapping IQRs
- **All findings qualified** with sample size (n=3 per cell)

---

## Phase 4: Update the Dashboard

### 4A. Current dashboard structure

File: `_metrics/dashboard-option-b.html` (self-contained HTML, Chart.js 4.4.7 from CDN)

Current charts (in order):
1. Summary cards (total cost + avg duration per profile)
2. Cost per task (bar)
3. Duration per task (bar)
4. Code Quality Radar — ex-bowling only, 3 axes (Function Decomposition, Cognitive Simplicity, Cyclomatic Control)
5. Max Function Length (bar)
6. Token Efficiency (bar — `output_tokens / lines_generated`)
7. Cost vs Cognitive Complexity scatter (Pareto)
8. Marginal Cost table (blank vs opinionated: cost premium, cognitive improvement, verdict)
9. Complexity Heatmap (green/yellow/red table)
10. Key Findings (text with n=1 caveats)

### 4B. What to update with multi-run data

1. **Replace hardcoded data** in the `profiles` object (lines ~283-320) with median values from n=3 runs
2. **Update summary cards** — totals will change
3. **Add error bars** or IQR ranges to bar charts (Chart.js supports `errorBars` plugin or custom drawing)
4. **Update Key Findings** text:
   - Remove "n=1" caveat (or update to "n=3")
   - Replace "observed" language with "consistently" where p < 0.05
   - Add any new findings from the expanded data
5. **Update subtitle** from "n=1 per cell (pilot run)" to "n=3 per cell"
6. **Radar chart** — use median values; consider showing IQR as a shaded band

### 4C. Dashboard helper functions already available

```javascript
function avg(arr) { ... }
function clamp(v, lo, hi) { ... }
function getField(profileKey, field) { ... }
function barChartOptions(label, formatter) { ... }
function makeBarDatasets(field) { ... }
```

Profile colors:
- main: `#3b82f6` (blue)
- blank: `#94a3b8` (gray)
- opinionated: `#f59e0b` (amber)

---

## Phase 5: Commit and Report

```bash
git add _metrics/
git commit -m "Run 45-run experiment (n=3) and update dashboard with statistical findings"
```

### Deliverables

1. 45 result JSON files in `_metrics/benchmarks/`
2. Updated `_metrics/dashboard-option-b.html` with n=3 data
3. Summary of findings: which claims are now statistically supported, which aren't

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `setup.sh` | Benchmark runner (`./setup.sh benchmark --task <name>`) |
| `benchmarks/tasks/*/` | 53 task directories (task.json, prompt.md, verify.sh, fixture/) |
| `benchmarks/score-metrics.py` | Shared Tier 1+2 quality metrics scorer |
| `benchmarks/analyzers/*.py` | 9 Tier 3 analyzer scripts |
| `benchmarks/analyzers/test_analyzers.py` | Consolidated test suite (16 checks) |
| `benchmarks/analyzers/test_duplicate_blocks.py` | Focused duplicate detector tests (3 checks) |
| `benchmarks/aggregate-results.py` | Multi-run aggregation (median/IQR per metric) |
| `_metrics/benchmarks/<profile>/<task>/*.json` | Per-run result files |
| `_metrics/dashboard-option-b.html` | Interactive dashboard (Chart.js) |
| `.claude/context-multi-run-protocol.md` | Statistical protocol (Wilcoxon, IQR, criteria) |
| `.claude/context-benchmark-execution.md` | Full benchmark execution guide |

## Constraints

- **Never run `./setup.sh use <branch>`** — it changes symlinks and disrupts the active Claude Code session
- **Benchmarks must run from a regular terminal** — `claude -p` conflicts with active Claude Code sessions
- **Use `git` directly for all git operations** — don't use `gh` for push/pull (causes HTTP 400 on this machine)
- **Tabs for indentation** (project convention)
- **No Co-Authored-By trailers** in commit messages
- **Commit style:** Brief imperative sentences ("Add X", "Fix Y", "Update Z")

## Known Limitations

- `personality_compliance` scores 80-83% for all profiles on ex-bowling — caused by magic number rule flagging domain constants (10 for pins, 300 for perfect game). This is a known limitation; the metric serves as a relative comparison tool.
- `overengineering_score` is 100 for all profiles on all tasks — not a differentiator, but useful as a gate.
- `naming_score` is 90-100 for all profiles — similarly not differentiating.
- The `llm_judge` analyzer exists but produces 0 scores (not wired up). Ignore it.
