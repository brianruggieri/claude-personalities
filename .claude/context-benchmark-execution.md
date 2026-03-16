# Context: Benchmark Execution — Run Expanded Suite Across Profiles

## What Was Done (Previous Session)

Built `benchmarks/import-tasks.py` and expanded the benchmark suite from 5 to 53 tasks:

| Source | Count | Prefix | Category | Difficulty |
|--------|-------|--------|----------|------------|
| HumanEval | 20 | `he-*` | function-completion | basic–advanced |
| MBPP | 10 | `mbpp-*` | function-completion | basic–intermediate |
| Exercism | 8 | `ex-*` | implementation | advanced–expert |
| ClassEval | 5 | `ce-*` | class-implementation | advanced–expert |
| Aider Refactoring | 5 | `rf-*` | refactoring | basic–expert |
| Original (hand-written) | 5 | mixed | mixed | trivial–basic |

All 48 imported tasks were validated against canonical solutions (SCORE:100). The importer script, task directories, and verify.sh scripts are all committed on `main`.

**Key commits (on main):**
```
81d10e2 Add Aider Refactoring importer and import refactoring tasks
35f0ee4 Add ClassEval importer and import 5 multi-method class tasks
d8097d6 Add Exercism importer and import 8 multi-function exercises
38085c2 Add MBPP importer and import 10 non-trivial tasks
5593cbf Fix code quality issues in import-tasks.py and regenerate HumanEval tasks
1f46c19 Add import-tasks.py with HumanEval importer and import 20 tasks
```

## What Remains

### Task A: Propagate benchmarks/ to blank and opinionated branches

The imported tasks currently only exist on `main`. The other profile branches need them too so the benchmark runner can find them when checked out on those branches.

```bash
# Propagate to blank
git checkout blank
git checkout main -- benchmarks/
git add benchmarks/
git commit -m "Sync benchmark tasks from main (53 tasks)"
git checkout main

# Propagate to opinionated
git checkout opinionated
git checkout main -- benchmarks/
git add benchmarks/
git commit -m "Sync benchmark tasks from main (53 tasks)"
git checkout main
```

**Warning:** Do NOT run `./setup.sh use <branch>` — that changes symlinks and disrupts the active session. Use raw `git checkout` for branch propagation only.

### Task B: Run benchmarks on all 3 profiles

**IMPORTANT:** The benchmark runner calls `claude -p` for each task. This MUST be run from a **regular terminal** (not inside a Claude Code session) because nested `claude -p` conflicts with an active session.

The runner detects the profile from the current git branch. To run all 3 profiles:

```bash
cd ~/git/claude_personalities

# Profile 1: main
git checkout main
./setup.sh benchmark
# Results → _metrics/benchmarks/main/<task>/result.json

# Profile 2: blank
git checkout blank
./setup.sh benchmark
# Results → _metrics/benchmarks/blank/<task>/result.json

# Profile 3: opinionated
git checkout opinionated
./setup.sh benchmark
# Results → _metrics/benchmarks/opinionated/<task>/result.json

# Return to main
git checkout main
```

**Cost estimate:** ~53 tasks × 3 profiles = ~159 `claude -p` invocations. Each uses `--max-budget-usd 5` so worst-case $795, but most tasks will cost $0.05–$1.00 each. Realistic total: $30–$80.

**Time estimate:** Each task has a timeout (30–240 seconds). With overhead, expect 2–4 hours for all 3 profiles.

**Subset option:** To test with fewer tasks first:
```bash
./setup.sh benchmark --task he-000-has-close-elements
./setup.sh benchmark --task mbpp-011-remove-occ
./setup.sh benchmark --task ex-bowling
./setup.sh benchmark --task ce-000-regex-utils
./setup.sh benchmark --task rf-001-command-output-hash
```

### Task C: Generate dashboard and analyze results

```bash
git checkout main
./setup.sh benchmark --report --html
# Output → _metrics/dashboard.html
```

Open `_metrics/dashboard.html` in a browser to see radar charts, cost bars, and results table.

**Key analysis questions:**
- Do Tier 2 tasks (ex-*, ce-*, rf-*) show meaningful score differences between profiles?
- Does the opinionated profile score higher on code quality metrics (naming, complexity, overengineering)?
- Does the blank profile show lower quality but lower cost?
- Which task categories differentiate profiles most?

### Task D: Commit results

```bash
git add _metrics/
git commit -m "Run benchmark expansion suite on all 3 profiles and regenerate dashboard"
```

## Key Files Reference

| File | Purpose |
|------|---------|
| `benchmarks/import-tasks.py` | Converter script (all 5 importers) |
| `benchmarks/tasks/*/` | 53 task directories |
| `benchmarks/score-metrics.py` | Shared Tier 1+2 quality metrics |
| `benchmarks/analyzers/` | 9 Tier 3 analyzer scripts |
| `setup.sh` (grep `_benchmark_run_task`) | Benchmark runner |
| `setup.sh` (grep `_benchmark_html_report`) | Dashboard generator |
| `_metrics/benchmarks/<profile>/<task>/result.json` | Per-task results |
| `_metrics/dashboard.html` | Interactive HTML dashboard |
| `.claude/context-benchmark-expansion.md` | Original expansion spec |
| `docs/superpowers/plans/2026-03-15-benchmark-expansion.md` | Implementation plan |

## Profiles (Branches)

| Branch | Personality | Expected Behavior |
|--------|-------------|-------------------|
| `main` | Base daily driver — full config, plugins, skills | Balanced quality and cost |
| `blank` | Clean slate — machine env only | Minimal overhead, basic code |
| `opinionated` | Strict engineering — TDD, quality thresholds | Higher quality, higher cost |
