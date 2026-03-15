# Context: Profiling System Phase 2 (Session Snapshots) & Phase 3 (Benchmarks)

## What Exists Already (Phase 1 — Complete)

Phase 1 built a static profile profiler. It's live on all 3 branches (main, blank, opinionated).

### Commands
```bash
./setup.sh profile                      # comparison table + capability matrix
./setup.sh profile --detail <branch>    # token breakdown, cost estimate, plugin inventory
./setup.sh profile --compare <a> <b>    # side-by-side diff with deltas
```

### Data Files (on all branches)
| File | Purpose |
|------|---------|
| `profile.json` | Per-branch manifest (name, category, capabilities) |
| `capabilities.json` | Shared capability vocabulary (8 capabilities → plugins) |
| `plugin-metadata.json` | Plugin skill/tool counts and listing token estimates |
| `benchmarks/base-overhead.json` | Claude Code base overhead (~13K tokens, Piebald-sourced) |
| `benchmarks/pricing.json` | Anthropic pricing constants for cost estimates |

### Architecture Decisions
- All commands live in `setup.sh` as bash functions
- JSON parsing via `python3 -c "import json; ..."` (no pip packages)
- Cross-branch reads via `git show <branch>:<file>` (no branch switching)
- Shared files (capabilities.json, plugin-metadata.json, benchmarks/) always read from `main` via `git show main:`
- Python outputs use `shlex.quote()` for injection safety, wrapped in try/except to always exit 0
- `_metrics/` is gitignored, created on first use

### Current Profile Numbers
| Profile | Tokens | Plugins | Skills | MCP Tools | Cost/turn (cache) |
|---------|--------|---------|--------|-----------|-------------------|
| blank | 231 | 0 | 0 | 0 | $0.0066 |
| main | 5,232 | 8 | 45 | 27 | $0.0091 |
| opinionated | 7,342 | 8 | 45 | 27 | $0.0102 |

---

## Phase 2: Session Snapshots

### Goal
Capture `~/.claude.json` session metrics after each Claude Code session and attribute them to the active profile. Over time, this accumulates real cost/latency data per profile.

### What ~/.claude.json Contains (Per-Project)

The file has a `projects` key, keyed by absolute path. Each project entry includes:
```json
{
  "lastCost": 25.11,
  "lastAPIDuration": 4215247,
  "lastAPIDurationWithoutRetries": 4213373,
  "lastToolDuration": 597504,
  "lastDuration": 57532737,
  "lastLinesAdded": 4157,
  "lastLinesRemoved": 321,
  "lastTotalInputTokens": 136645,
  "lastTotalOutputTokens": 250024,
  "lastTotalCacheCreationInputTokens": 1197103,
  "lastTotalCacheReadInputTokens": 31684885,
  "lastTotalWebSearchRequests": 0,
  "lastModelUsage": {
    "claude-sonnet-4-6": {
      "inputTokens": 9464,
      "outputTokens": 207051,
      "cacheReadInputTokens": 27565592,
      "cacheCreationInputTokens": 771575,
      "costUSD": 23.83
    }
  }
}
```

Key limitation: only `last*` values exist — each new session overwrites the previous. That's why snapshots are needed to accumulate history.

### Command: `./setup.sh snapshot`

**Default (A):** Captures metrics for the current directory (`$PWD`). Looks up `$PWD` in `~/.claude.json`'s `projects` key. If found, extracts the `last*` fields and writes a timestamped snapshot.

**Optional `--all` flag:** Captures metrics for all projects in `~/.claude.json`.

**Execution flow:**
1. Read current branch → profile name
2. Read `~/.claude.json` via python3
3. Find the project entry matching `$PWD` (or all projects if `--all`)
4. Create `_metrics/sessions/<profile>/` if needed
5. Write `_metrics/sessions/<profile>/<ISO-timestamp>.json`
6. Print summary: cost, duration, cache hit rate

**Snapshot format:**
```json
{
  "profile": "main",
  "timestamp": "2026-03-15T16:00:00Z",
  "project": "/path/to/some-project",
  "cost_usd": 25.11,
  "duration_seconds": 57532,
  "api_duration_seconds": 4215,
  "total_input_tokens": 136645,
  "total_output_tokens": 250024,
  "cache_creation_tokens": 1197103,
  "cache_read_tokens": 31684885,
  "cache_hit_rate": 0.964,
  "lines_added": 4157,
  "lines_removed": 321,
  "model_usage": {
    "claude-sonnet-4-6": {
      "inputTokens": 9464,
      "outputTokens": 207051,
      "cacheReadInputTokens": 27565592,
      "cacheCreationInputTokens": 771575,
      "costUSD": 23.83
    }
  }
}
```

### Optional SessionEnd Hook

For hands-free capture, users can add to their `claude/settings.json`:
```json
{
  "hooks": {
    "SessionEnd": [
      {
        "type": "command",
        "command": "~/git/claude_personalities/setup.sh snapshot --quiet"
      }
    ]
  }
}
```

Not in any profile by default — opt-in only. Document this in the usage text.

### Enriched Profile Output

When `_metrics/sessions/` has data, `./setup.sh profile` should append a "Session Averages" section:
```
Session Averages (from _metrics/sessions/)
────────────────────────────────────────────────────────────────────────────
Profile     Sessions  Avg Cost  Avg Duration  Avg Cache Hit%
main            12     $8.42      22m 15s        97.2%
blank            3     $3.15       9m 40s        94.8%
```

This means modifying `_profile_table()` to check for session data and append if it exists.

### Implementation Notes
- `~/.claude.json` may not exist or may not have an entry for `$PWD` — handle gracefully
- Duration fields in `~/.claude.json` are in milliseconds — convert to seconds for display
- Cache hit rate = `lastTotalCacheReadInputTokens / (lastTotalCacheReadInputTokens + lastTotalCacheCreationInputTokens + lastTotalInputTokens)`
- The `--quiet` flag should suppress stdout (for the hook) but still write the snapshot file
- Use the same python3 + shlex.quote() safety pattern from Phase 1

### Setup.sh Integration
Add to the usage text:
```
Metrics:
  snapshot                         Capture current session metrics for active profile
  snapshot --all                   Capture metrics for all projects
```

Add to the case dispatch:
```bash
snapshot)     shift; cmd_snapshot "$@" ;;
```

---

## Phase 3: Benchmark System

### Goal
Run standardized tasks against profiles and compare results. Each task exercises a specific capability, is scored automatically, and accumulates results in `_metrics/benchmarks/`.

### Benchmark Task Structure

Tasks live in `benchmarks/tasks/` (shared across all branches). Auto-discovered by globbing `benchmarks/tasks/*/task.json`.

```
benchmarks/tasks/
  hello-world/
    task.json           # metadata
    prompt.md           # exact prompt sent to Claude Code
    verify.sh           # scoring script (exit 0 = pass, exit 1 = fail)
    expected/           # reference outputs for verification
  fix-python-bug/
    task.json
    prompt.md
    verify.sh
    fixture/            # starter files placed in working dir before task
```

### task.json Format
```json
{
  "name": "fix-python-bug",
  "description": "Fix a failing test in a small Python project",
  "category": "debugging",
  "capability": "tdd-workflow",
  "difficulty": "basic",
  "timeout": 120,
  "scoring": "binary",
  "metrics": ["correctness", "cost", "duration", "token_efficiency"]
}
```

### Benchmark Runner: `./setup.sh benchmark`

**Execution flow:**
1. Create a temp working directory
2. Copy `fixture/` files into it (if present)
3. Run: `claude --print --prompt "$(cat prompt.md)" --cwd $tmpdir`
4. Run: `verify.sh $tmpdir` (exit 0 = pass, exit 1 = fail)
5. Capture `~/.claude.json` metrics (same as snapshot)
6. Store results in `_metrics/benchmarks/<profile>/<task>/<timestamp>.json`
7. Clean up temp directory

**Flags:**
- `./setup.sh benchmark` — run all tasks against current profile
- `./setup.sh benchmark --task <name>` — run one specific task
- `./setup.sh benchmark --report` — show results table (no execution)

### Result Format
```json
{
  "profile": "main",
  "task": "fix-python-bug",
  "timestamp": "2026-03-15T16:00:00Z",
  "passed": true,
  "score": 1,
  "cost_usd": 0.42,
  "duration_seconds": 34,
  "total_input_tokens": 12500,
  "total_output_tokens": 3200,
  "cache_read_tokens": 45000,
  "cache_creation_tokens": 8500,
  "model": "claude-opus-4-6"
}
```

### Regression Detection

When multiple runs exist for a task, compare the latest against the historical average. Flag:
- Cost increase >10%
- pass → fail transition

```
⚠ Regression: "fix-python-bug" on main
  Previous avg cost: $0.42 → Current: $0.58 (+38%)
  Possible cause: CLAUDE.md grew by 1,200 tokens since last benchmark
```

### Starter Benchmark Suite (5 Tasks)

| Task | Category | Capability | What It Tests |
|------|----------|-----------|---------------|
| `hello-world` | baseline | (none) | Baseline cost — every profile passes, measures pure overhead |
| `fix-python-bug` | debugging | tdd-workflow | Does TDD skill reduce debugging time/cost? |
| `create-react-component` | frontend | frontend-design | Does frontend-design/impeccable add value? |
| `write-unit-tests` | testing | tdd-workflow | Does TDD workflow skill improve test quality? |
| `review-code-diff` | review | code-review | Does code-review plugin add value? |

Each task needs:
1. `task.json` with metadata
2. `prompt.md` with a clear, self-contained task description
3. `verify.sh` with automated pass/fail checking
4. `fixture/` with starter files (for tasks that need them)
5. `expected/` with reference outputs (for tasks that verify specific output)

### Design Constraints
- Benchmarks are expensive (real Claude sessions) — always opt-in, never automatic
- LLM output is non-deterministic — report run count and variance
- Tasks must be self-contained — no network, no external deps
- `benchmarks/` is on all branches (shared infrastructure, not profile content)
- The `--report` flag should work without running any benchmarks (reads `_metrics/`)

### Setup.sh Integration
Add to usage text:
```
Benchmarking:
  benchmark                        Run all benchmark tasks against current profile
  benchmark --task <name>          Run a specific benchmark task
  benchmark --report               Show benchmark results across profiles
```

Add to case dispatch:
```bash
benchmark)    shift; cmd_benchmark "$@" ;;
```

### Enriched Profile Output

When benchmark data exists, `./setup.sh profile` should append:
```
Benchmark Results (last run per task)
────────────────────────────────────────────────────────────────────────────
Task                     blank    main    opinionated
fix-python-bug           ✓ $0.38  ✓ $0.42  ✓ $0.40
create-react-component   ✗        ✓ $1.20  ✓ $1.15
write-unit-tests         ✓ $0.55  ✓ $0.48  ✓ $0.45

Score    1/3 (33%)   3/3 (100%)  3/3 (100%)
Avg cost   $0.47       $0.70       $0.67
```

---

## Implementation Order

**Phase 2 first** (simpler, immediately useful):
1. Write `cmd_snapshot` function in setup.sh
2. Add `--quiet` flag support
3. Add session averages to `_profile_table()` output
4. Update usage text and dispatch
5. Test manually (run a session, take a snapshot, check output)
6. Propagate setup.sh to blank and opinionated branches

**Phase 3 second** (more complex, depends on Phase 2 for metrics capture):
1. Create the 5 benchmark task dirs with task.json, prompt.md, verify.sh, fixture/
2. Write `cmd_benchmark` function (runner + report modes)
3. Add regression detection
4. Add benchmark results to `_profile_table()` output
5. Update usage text and dispatch
6. Run benchmarks against each profile, verify results
7. Propagate to all branches

---

## References

- **Design spec:** `docs/superpowers/specs/2026-03-15-profile-benchmarking-design.md`
- **Phase 1 plan:** `docs/superpowers/plans/2026-03-15-profile-benchmarking-phase1.md`
- **setup.sh:** The profiler functions start at the `# ─── Profiler` comment
- **~/.claude.json:** Lives at `~/.claude.json` (symlinked from `home/.claude.json` in this repo)
- **Piebald-AI:** https://github.com/Piebald-AI/claude-code-system-prompts — base overhead reference
- **Claude Code cost docs:** https://code.claude.com/docs/en/costs — official cost guidance
- **claude-flow benchmarking:** https://github.com/ruvnet/ruflo/wiki/Performance-Benchmarking — benchmark methodology patterns

## Working Rules
- Work on `main` branch. Don't touch `claude/` or `home/`.
- Use tabs for indentation in setup.sh.
- All python3 calls must exit 0 (try/except), use sys.argv for input, shlex.quote() for output.
- Propagate setup.sh + shared files to blank and opinionated after completing each phase.
- Use `/brainstorm` if the task design needs refinement before implementation.
