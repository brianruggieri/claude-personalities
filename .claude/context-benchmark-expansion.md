# Context: Benchmark Task Expansion — Importing Open-Source Test Suites

## Goal

Expand the benchmark suite from 5 hand-written tasks to 50+ by importing from open-source LLM code benchmarks. Write a converter script that transforms external benchmark formats into our task directory structure, then import and validate the tasks.

## Current System (already built)

The benchmark system lives in `~/git/claude_personalities`. Each task is a directory:

```
benchmarks/tasks/<name>/
  task.json           # metadata (name, category, difficulty, timeout, expected_complexity)
  prompt.md           # exact prompt sent to claude -p
  verify.sh           # scoring script (exit 0 = pass, exit 1 = fail, prints SCORE:<0-100>)
  fixture/            # optional starter files placed in working dir before task
```

The runner (`./setup.sh benchmark`) creates a tmpdir, copies fixtures, runs `claude -p --append-system-prompt <profile_CLAUDE.md>`, then runs verify.sh + 9 analyzers (security, naming, complexity, duplicates, personality compliance, etc.). Results are JSON in `_metrics/benchmarks/<profile>/<task>/`.

**Current 5 tasks:** hello-world, fix-python-bug, create-react-component, write-unit-tests, review-code-diff.

**Problem:** These are too simple to differentiate personality profiles. All 3 profiles score nearly identically because a one-line bug fix doesn't exercise TDD rules or function length limits.

## What to Import

### Tier 1 — Bulk import via converter script (target: 30 tasks)

**HumanEval** (MIT, github.com/openai/human-eval)
- 164 Python function-completion problems in JSONL
- Format: `task_id`, `prompt` (function signature + docstring), `canonical_solution`, `entry_point`, `test`
- Conversion: `prompt.md` = "Complete this function:" + docstring/signature; `fixture/` = stub file; `verify.sh` = run test assertions
- Cherry-pick 20 medium-difficulty problems (skip trivial ones like "return a+b")

**MBPP** (CC-BY-4.0, github.com/google-research/google-research/tree/master/mbpp)
- 974 basic Python problems in JSONL
- Format: `text` (task description), `code` (solution), `test_list` (3 assert statements)
- Conversion: trivially scriptable
- Cherry-pick 10 problems with non-trivial logic

### Tier 2 — Hand-curated for profile differentiation (target: 15 tasks)

**Aider Exercism** (Apache-2.0, github.com/Aider-AI/aider)
- 133 Python exercises with existing code + tests
- Natural "edit existing code" format — maps directly to our fixture/ structure
- Pick 5-8 exercises that require multi-function implementations

**Aider Refactoring** (github.com/Aider-AI/refactor-benchmark)
- 89 Python refactoring tasks from real repos
- Tests completeness, laziness, code structure
- THIS IS THE BEST SOURCE for profile differentiation — opinionated should outperform blank
- Pick 3-5 refactoring tasks

**ClassEval** (Apache-2.0, github.com/FudanSELab/ClassEval)
- 100 class-level generation tasks, ~33 tests each
- Tests design decisions, naming, encapsulation
- Pick 4-5 class tasks with interesting design choices

### Tier 3 — Optional extras

**BigCodeBench Instruct** (Apache-2.0, HuggingFace bigcode/bigcodebench)
- 1,140 library-usage tasks, but many require heavy deps (numpy, pandas)
- Only pick 3-5 that use stdlib only

## Converter Script Design

Create `benchmarks/import-tasks.py` that:

1. Reads source format (JSONL for HumanEval/MBPP, per-directory for Exercism/ClassEval)
2. Creates our directory structure (task.json, prompt.md, verify.sh, fixture/)
3. Generates verify.sh that runs the source's test assertions
4. Sets appropriate `expected_complexity` in task.json based on solution size
5. Supports `--source humaneval|mbpp|exercism|classeval` flag
6. Supports `--filter` to select specific task IDs
7. Supports `--dry-run` to preview without writing

The verify.sh it generates should:
- Run the tests and report pass/fail
- Output SCORE based on tests passed / total
- Follow our conventions (set -euo pipefail, exit 0 for pass, exit 1 for fail)

## Implementation Order

1. Write `benchmarks/import-tasks.py` with HumanEval support first (simplest format)
2. Download HumanEval JSONL, import 20 tasks, validate they work
3. Add MBPP support, import 10 tasks
4. Add Exercism support (requires cloning aider repo), import 5-8 tasks
5. Add ClassEval support, import 4-5 tasks
6. Run full benchmark suite across all 3 profiles
7. Generate dashboard and analyze differentiation

## Working Rules

- Work on `main` branch
- Don't touch `claude/` or `home/` (profile content)
- Use tabs in bash (setup.sh), spaces in python
- All python3 calls must exit 0 (try/except)
- verify.sh scripts must output SCORE:<0-100>
- Propagate shared files (setup.sh, benchmarks/) to blank and opinionated after completing
- Don't run `./setup.sh use` during a Claude Code session
- No pip installs without approval — use python3 stdlib only for the converter
- Downloaded source data goes in `benchmarks/sources/` (gitignored)

## Key Files to Read First

- `.claude/context-profiling-phase2-3.md` — Phase 2+3 spec (snapshot + benchmark system)
- `.claude/context-metrics-research.md` — metrics and visualization research
- `setup.sh` — the benchmark runner (grep for `_benchmark_run_task`)
- `benchmarks/tasks/fix-python-bug/` — example of a well-structured task with fixture
- `benchmarks/score-metrics.py` — shared Tier 1+2 metrics scorer
- `benchmarks/analyzers/` — Tier 3 analyzer scripts

## Dependencies to Download

These need to be fetched before importing (no pip needed, just the data files):

```bash
mkdir -p benchmarks/sources
# HumanEval
curl -L https://github.com/openai/human-eval/raw/master/data/HumanEval.jsonl.gz -o benchmarks/sources/HumanEval.jsonl.gz
gunzip benchmarks/sources/HumanEval.jsonl.gz

# MBPP
curl -L https://raw.githubusercontent.com/google-research/google-research/master/mbpp/mbpp.jsonl -o benchmarks/sources/mbpp.jsonl

# Exercism (clone aider repo for task definitions)
git clone --depth 1 https://github.com/Aider-AI/exercism-python.git benchmarks/sources/exercism-python

# ClassEval
git clone --depth 1 https://github.com/FudanSELab/ClassEval.git benchmarks/sources/ClassEval
```

Add to .gitignore: `benchmarks/sources/`
