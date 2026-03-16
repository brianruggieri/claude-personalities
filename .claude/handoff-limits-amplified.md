# Handoff: Limits-Amplified Profile Analysis

## What You're Picking Up

A benchmarking system that measures whether different Claude Code personality profiles produce measurably different code. We've run 108+ benchmark runs across 9 tasks and 3 profiles, plus a 12-run isolation experiment. The key discovery:

**The only personality rules that measurably improve code structure are hard limits on function length and cyclomatic complexity.** TDD mandates, planning requirements, engineering philosophy, and 900+ lines of other instructions produce zero measurable effect.

A new "limits-amplified" profile has been created with tighter thresholds (max 20 lines/function, complexity ≤ 5, cognitive ≤ 8) and needs to be run across all 9 tasks.

## What's Been Done

### Experiment History

| Experiment | Runs | Finding |
|-----------|------|---------|
| Pilot (n=1) | 15 | ex-bowling shows differentiation, 4 tasks identical |
| Multi-run (n=4) | 60 | ex-bowling confirmed with non-overlapping IQRs |
| High-latitude follow-up (n=3) | 36 | 4 new "design latitude" tasks added — 3 of 4 still identical. 7 of 9 total produce identical code |
| **Isolation experiment** (n=3) | 12 | Tested TDD-only, limits-only, planning-only on ex-bowling. **Limits-only is the active ingredient.** |

### Isolation Experiment Results (the breakthrough)

On ex-bowling (the one differentiating task):

| Variant | Cognitive Max | Max Func Length | vs Blank |
|---------|:---:|:---:|:---|
| blank (control) | 34 [27-41] | 50 [41-64] | — |
| tdd-only | 37 [35-38] | 60 [59-61] | Worse than blank |
| **limits-only** | **7 [5-11]** | **14 [14-14]** | **5x simpler, 4x shorter** |
| planning-only | 29 [26-37] | 56 [47-60] | No difference from blank |
| opinionated (full) | 12 [11-17] | 19 [17.5-23.5] | Good, but limits-only is better |

Key insight: limits-only (7 lines of rules) outperforms full opinionated (~1000 lines). The other rules may dilute the effect.

## What Needs Doing

### Phase 1: Run the limits-amplified experiment

The experiment script is ready. Run from a **regular terminal** (not inside Claude Code):

```bash
cd ~/git/claude_personalities && ./run-isolation-experiment.sh
```

This runs: 1 profile (variant-limits-amplified) × 9 tasks × 3 reps = 27 runs
Estimated cost: ~$8-10, time: ~25-35 minutes.

The limits-amplified profile (`_experiment/claude-md-limits-amplified.md`) adds tighter thresholds on top of blank:
- Functions: max 20 lines (was 50 in opinionated)
- Cyclomatic complexity: max 5 (was 8)
- Cognitive complexity: max 8 (new — opinionated didn't have this)
- Max 3 positional params, no magic numbers, no commented code, no single-letter vars

### Phase 2: Analyze results

After the experiment completes:

```bash
python3 benchmarks/aggregate-results.py _metrics/
```

Compare `variant-limits-amplified` against `blank`, `opinionated`, and `variant-limits-only` on all 9 tasks. Key questions:

1. **Does limits-amplified beat limits-only on ex-bowling?** (tighter thresholds → even more decomposition?)
2. **Does limits-amplified differentiate on tasks where limits-only/opinionated didn't?** (do tighter thresholds force decomposition on currently-identical tasks?)
3. **Does it break anything?** (forced over-decomposition on simple tasks? test failures?)
4. **What's the cost impact?** (does tighter decomposition increase token usage?)

### Phase 3: Update the dashboard

File: `_metrics/dashboard-option-b.html`

The dashboard currently has 9 tasks × 3 profiles (blank, main, opinionated). You need to:

1. Add `variant-limits-amplified` as a 4th profile in the dashboard data
2. Add it to the `profiles` object with color `#10b981` (emerald/green — stands out from existing blue/gray/amber)
3. Add it to `PROFILE_ORDER`
4. Update the executive summary with the isolation experiment findings
5. Update the findings text

The dashboard uses Chart.js 4.4.7 and is self-contained HTML. All charts read from the `profiles` data object automatically — adding a 4th profile should cascade to all charts.

### Phase 4: Build the production profile

If limits-amplified performs well, create a proper git branch for it:

1. Create branch `limits-amplified` from `blank`
2. Copy `_experiment/claude-md-limits-amplified.md` to `claude/CLAUDE.md`
3. Copy blank's `claude/settings.json` (no hooks needed — the rules work purely through the prompt)
4. Sync `benchmarks/` from main
5. Consider whether this should replace `opinionated` or coexist as a new tier

## Key Files

| File | Purpose |
|------|---------|
| `run-isolation-experiment.sh` | Experiment runner (currently configured for limits-amplified × 9 tasks) |
| `_experiment/claude-md-limits-amplified.md` | The new profile's CLAUDE.md (blank + tight limits) |
| `_experiment/claude-md-limits-only.md` | Original limits-only variant (opinionated's thresholds) |
| `_experiment/claude-md-tdd-only.md` | TDD-only variant (proved ineffective) |
| `_experiment/claude-md-planning-only.md` | Planning-only variant (proved ineffective) |
| `_metrics/dashboard-option-b.html` | Interactive dashboard (Chart.js) |
| `benchmarks/aggregate-results.py` | Multi-run aggregation (median/IQR) |
| `benchmarks/analyzers/test_analyzers.py` | Consolidated test suite (16 checks) |
| `.claude/context-multi-run-protocol.md` | Statistical methodology |

## Existing Result Data

Results live in `_metrics/benchmarks/<profile>/<task>/<timestamp>.json`. Current profiles with data:

| Profile | Tasks with data | Runs per task |
|---------|----------------|---------------|
| blank | 9 + ex-bowling extras | 3-7 |
| main | 9 | 3-4 |
| opinionated | 9 | 3-4 |
| variant-tdd-only | ex-bowling only | 3 |
| variant-limits-only | ex-bowling only | 3 |
| variant-planning-only | ex-bowling only | 3 |
| variant-limits-amplified | **pending** | 0 |

## Constraints

- **Never run `./setup.sh use <branch>`** — changes symlinks, disrupts active session
- **Benchmarks must run from a regular terminal** — `claude -p` conflicts with Claude Code
- **Use `git` directly** — don't use `gh` for push/pull (HTTP 400 on this machine)
- **Tabs for indentation**, no Co-Authored-By trailers
- **Commit style:** Brief imperative sentences

## The Big Picture Question

The user's daily driver is `opinionated`. They want to know: **can we build a personality that beats opinionated on complex tasks?**

The data says yes — limits-only already beats full opinionated on ex-bowling (cognitive 7 vs 12, func_len 14 vs 19). The hypothesis is that limits-amplified (even tighter thresholds) will:
1. Maintain or improve the ex-bowling advantage
2. Potentially unlock differentiation on tasks that were previously identical
3. Do this at lower cost than opinionated (fewer prompt tokens, no TDD/planning overhead)

If this works, it fundamentally changes the profile strategy: **a 10-line CLAUDE.md with tight hard limits outperforms a 1000-line personality with philosophy, TDD, planning, and hooks.**
