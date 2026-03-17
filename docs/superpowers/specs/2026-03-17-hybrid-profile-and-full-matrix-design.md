# Hybrid Profile + Full Benchmark Matrix

**Date:** 2026-03-17
**Status:** Approved
**Workstreams:** Profile creation, benchmark execution, dashboard + analysis

---

## 1. Problem Statement

Benchmark data shows that the `variant-limits-amplified` profile produces the best cost/quality tradeoff, but it's a bare variant — no plugins, no permissions, no daily-driver workflow guidance. The `opinionated` profile has full tooling but costs 61% more than blank with diminishing returns on 5 of 9 tasks. No profile currently combines proven behavioral rules with lean production tooling.

Additionally, the benchmark matrix is sparse: only 9 of 53 tasks have data, and only for 3-4 profiles. The dashboard cannot support statistically valid claims or deep cross-profile analysis.

## 2. Goals

1. **Create a `hybrid` profile** — a full daily-driver branch combining variant-limits-amplified's data-proven code constraints with curated tooling and slim workflow rules. Target: ~80 lines CLAUDE.md, 4 plugins, deny rules, no hooks.
2. **Pilot validation** — 5 profiles x 5 tasks x 3 reps (75 runs) to confirm hybrid sits on the efficient frontier before committing to full expansion.
3. **Full matrix expansion** — 5 profiles x 53 tasks x 3 reps (795 runs) with LLM judge enabled, producing the complete dataset.
4. **Dashboard upgrade** — Expand from current 4-profile/9-task view (blank, opinionated, variant-limits-amplified, minimalism — main is absent despite having data) to 5-profile/53-task deep analysis with statistical significance, task-type grouping, and profile recommendations.

## 3. Hybrid Profile Design

### 3.1 CLAUDE.md (~78 lines)

Three sections, in order:

**Machine Environment (~38 lines)** — Identical to all other profiles. macOS, nvm, rustup, pyenv setup. Non-negotiable infrastructure.

**Code Standards — Hard Limits (~25 lines)** — Carried forward from variant-hybrid, unchanged:
- Functions: Max 20 lines
- Cyclomatic complexity: Max 5 per function
- Cognitive complexity: Max 8 per function
- Conciseness bias: Don't decompose trivial problems
- No unnecessary abstractions (no single-use wrappers/adapters)
- No magic numbers (except 0, 1, -1)
- No commented-out code

**Workflow (~15 lines)** — Cherry-picked from main:
- Global Preferences: tabs, npm, imperative commit style, auto-run tests, explain reasoning, cost-effective execution, subscription-only Claude usage
- When to Ask vs. Proceed: ask if uncertain; always confirm destructive actions
- Git: no co-authored-by trailers, worktrees in `.worktrees/`, one per task, cleanup after merge
- Plans/docs in `.claude/` directory
- GitHub: use `git` for push/pull (not `gh`), PRs via `gh pr create`
- Never do: system Node, commit secrets, push to main without asking, install global packages without asking

**What is intentionally excluded:**
- Orchestration Guide (16 lines) — superpowers plugin handles this via skills
- Skills Reference (25 lines) — plugins self-document; redundant with only 4 enabled
- Port Management (12 lines) — niche; belongs in project-level CLAUDE.md
- Engineering Philosophy prose (opinionated has ~30 lines) — the hard limits speak for themselves
- Testing Discipline section (opinionated has ~20 lines) — "auto-run tests" preference + superpowers TDD skill covers this
- Pre-commit checklist (opinionated has ~15 lines) — overhead without measured quality gain

### 3.2 settings.json

```json
{
  "cleanupPeriodDays": 99999,
  "permissions": {
    "allow": [
      "Bash(npx:*)", "Bash(npm:*)", "Bash(node:*)",
      "Bash(python3:*)", "Bash(pip3:*)", "Bash(pip:*)",
      "Bash(source:*)", "Bash(git:*)", "Bash(gh:*)",
      "Bash(claude:*)", "Bash(ls:*)", "Bash(cp:*)",
      "Bash(rm:*)", "Bash(mkdir:*)", "Bash(wc:*)",
      "Bash(head:*)", "Bash(tail:*)", "Bash(cat:*)",
      "Bash(tee:*)", "Bash(grep:*)",
      "WebSearch"
    ],
    "deny": [
      "Read(~/.ssh/**)", "Read(~/.aws/**)",
      "Read(~/.gnupg/**)", "Read(~/.git-credentials)",
      "Read(~/Library/Keychains/**)",
      "Bash(rm -rf *)", "Bash(rm -fr *)",
      "Bash(sudo *)", "Bash(git push --force*)",
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
  "attribution": { "commit": "", "pr": "" }
}
```

**Plugin rationale:**
- **context7** — Documentation lookup. Zero overhead, high value for unfamiliar APIs.
- **superpowers** — Brainstorming, TDD, plans, debugging workflows. Structured engineering that complements the hard limits.
- **code-review** — PR review. Closes the quality feedback loop.
- **typescript-lsp** — Type checking. Auto-invoked, zero behavioral overhead.

**Excluded plugins:**
- frontend-design, impeccable — UI/design focused, not relevant to coding quality benchmarks
- ralph-loop — Autonomous loop runner, niche use case
- playwright — Headless browser QA, adds weight without coding quality benefit

**Excluded from main's settings:**
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var — experimental feature, not needed
- `skipDangerousModePermissionPrompt` — keep the safety prompt
- `extraKnownMarketplaces` — only needed for impeccable plugin
- `statusLine` — nice-to-have, can add later if desired
- `worktree.symlinkDirectories` — project-specific, not profile-level
- Hooks (PreToolUse) — deny rules provide the safety backstop without per-tool-call overhead
- `Bash(bun:*)`, `Bash(uvx:*)`, `Bash(plutil:*)`, `Bash(tmux:*)` — niche, add per-project

### 3.3 Branch Structure

The hybrid profile lives on a new `hybrid` git branch (not `variant-hybrid`). This is a first-class profile alongside main, blank, and opinionated.

Files on the `hybrid` branch:
- `claude/CLAUDE.md` — the ~78 line personality
- `claude/settings.json` — the settings above
- `claude/MEMORY.md` — empty (fresh profile)
- `setup.sh` — synced from main (shared infrastructure)
- `benchmarks/` — synced from main (shared task suite)

The existing `variant-hybrid` branch is preserved for historical comparison but is superseded by `hybrid`. Note that variant-hybrid was a bare variant with zero plugins, default permissions, and no workflow guidance — the new `hybrid` branch is the first time these code-standard rules are combined with curated settings.json and daily-driver tooling.

### 3.4 What Benchmarks Measure vs. What They Don't

The benchmark runner (`setup.sh benchmark`) invokes `claude -p` with `--dangerously-skip-permissions` and injects only `claude/CLAUDE.md` via `--append-system-prompt`. It does **not** load or apply `settings.json`. This means:

- **Benchmarked:** CLAUDE.md behavioral rules (code standards, workflow guidance, conciseness bias)
- **Not benchmarked:** Plugin effects, deny rules, permission modes, hooks, effort level

The settings.json design (section 3.2) is validated only during daily-driver usage. All benchmark comparisons measure pure CLAUDE.md behavioral effects — which is the correct isolation for answering "do personality rules change code quality?"

## 4. Benchmark Execution Strategy

### 4.1 Phase 1: Pilot Validation

**Matrix:** 5 profiles x 5 tasks x 3 reps = 75 runs
**Profiles:** blank, main, opinionated, hybrid, variant-limits-amplified
**Tasks:** he-000-has-close-elements, mbpp-011-remove-occ, ex-bowling, ce-000-regex-utils, rf-001-command-output-hash
**Cost estimate:** $12-20
**Duration:** 1-2 hours unattended
**LLM Judge:** Off (save cost for pilot)

**Existing data reuse:** blank, main, opinionated, and variant-limits-amplified have 1-3 existing runs per task. Top up to 3 reps each. Hybrid needs all 15 runs fresh.

**Execution:** From regular terminal (not Claude Code):
```bash
# Per profile (after ./setup.sh use <profile>):
for task in he-000-has-close-elements mbpp-011-remove-occ ex-bowling ce-000-regex-utils rf-001-command-output-hash; do
  for rep in 1 2 3; do
    ./setup.sh benchmark --task "$task"
  done
done
```

**Exit criteria before Phase 2:**
- Hybrid cognitive_complexity_max within 20% of variant-limits-amplified on ex-bowling
- Hybrid cost_usd within 15% of blank's median across all 5 tasks
- If both criteria fail, tune CLAUDE.md and re-run hybrid's 15 tasks before expanding

### 4.2 Phase 2: Full Expansion

**Matrix:** 5 profiles x 53 tasks x 3 reps = 795 runs
**Cost estimate:** $150-400 (judge roughly doubles per-run cost)
**Duration:** 6-8 hours unattended
**LLM Judge:** Enabled (`BENCHMARK_JUDGE=1`) for all runs

**Execution:** Same loop pattern, all 53 tasks:
```bash
BENCHMARK_JUDGE=1
for task in benchmarks/tasks/*/; do
  for rep in 1 2 3; do
    ./setup.sh benchmark --task "$(basename "$task")"
  done
done
```

**Infrastructure prerequisite:** Before running on blank and opinionated branches, sync `benchmarks/` and `setup.sh` from main:
```bash
git checkout blank && git checkout main -- benchmarks/ setup.sh && git commit -m "Sync benchmark suite from main"
git checkout opinionated && git checkout main -- benchmarks/ setup.sh && git commit -m "Sync benchmark suite from main"
git checkout hybrid && git checkout main -- benchmarks/ setup.sh && git commit -m "Sync benchmark suite from main"
```

### 4.3 Phase 3: Aggregation and Analysis

**Step 1 — Aggregate:**
```bash
python3 benchmarks/aggregate-results.py _metrics
```
Produces median + IQR per (profile, task) cell.

**Step 2 — Regenerate base dashboard:**
```bash
./setup.sh benchmark --report --html
```
This generates `_metrics/dashboard.html` (auto-generated). The existing hand-curated `_metrics/dashboard-option-b.html` is a separate file. Dashboard upgrades below apply to the auto-generated dashboard by modifying the `_benchmark_html_report` function in setup.sh.

**Step 3 — Dashboard upgrades (code changes to setup.sh's report generator):**

1. **Add hybrid profile** — new color (#ec4899 pink), new column in all charts and tables
2. **Task grouping** — group 53 tasks by source (HumanEval, MBPP, Exercism, ClassEval, Aider, Hand-written) with collapsible sections
3. **Judge score radar** — 6-axis radar chart (readability, naming, error_handling, idiomatic, abstraction, overall) per profile, aggregated across all tasks. **Prerequisite:** extend `aggregate-results.py` to include judge score fields (`judge_score`, `judge_readability`, `judge_naming`, `judge_error_handling`, `judge_idiomatic`, `judge_abstraction`) in its KEY_METRICS list
4. **Statistical significance indicators** — highlight cells where profile IQRs don't overlap (visual: bold border or asterisk)
5. **Profile recommendation engine** — "Best profile for X" cards based on task complexity bands:
   - Trivial (HumanEval simple): which profile is cheapest with identical quality?
   - Moderate (MBPP, ClassEval): where do constraints start paying off?
   - Complex (Exercism, Aider refactoring): where is the quality ceiling?
6. **Diminishing returns curve** — scatter: prompt line count (x) vs. quality composite score (y) per profile
7. **Task-type analysis** — do profiles differentiate more on algorithmic vs. architectural vs. refactoring tasks?

## 5. Analysis Deliverables

The final dashboard and analysis should answer these questions:

1. **Does hybrid deliver?** Cost within 15% of blank, quality within 20% of variant-limits-amplified, across 53 tasks not just 5.
2. **When do profiles matter?** On which task types and complexity bands do personality rules measurably change output quality?
3. **What's the cost of strictness?** Diminishing returns curve — at what point does adding more CLAUDE.md content stop improving code?
4. **Per-profile verdict:** One-line recommendation for each profile (daily driver, cost-sensitive, quality-critical, control).
5. **Hybrid vs. opinionated:** Direct comparison — does hybrid achieve opinionated's quality goals at lower cost?

## 6. Success Criteria

- [ ] Hybrid branch created with CLAUDE.md (~78 lines) and settings.json (4 plugins, deny rules)
- [ ] Pilot (75 runs) completes with hybrid meeting exit criteria
- [ ] Full expansion (795 runs) completes with judge scores for all cells
- [ ] Dashboard upgraded to show all 5 profiles across 53 tasks with statistical indicators
- [ ] Analysis answers all 5 questions in section 5 with data-backed claims
- [ ] All claims qualified with sample size and significance level

### Statistical Methodology Note

Wilcoxon signed-rank tests are paired **by task** (53 pairs in full expansion), not by repetition. With 53 tasks, p<0.05 is achievable. The 3 reps per cell provide within-cell spread estimation (IQR) but are not the unit of statistical testing. Pilot phase (5 tasks) uses threshold-based exit criteria (within 20%, within 15%) rather than significance tests, since 5 pairs cannot reach p<0.05 with Wilcoxon.

## 7. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Hybrid fails pilot exit criteria | Delays full expansion by ~1 hour | Tune CLAUDE.md (adjust function limit or conciseness rules) and re-run 15 tasks |
| Full expansion cost exceeds $400 | Budget overrun | Monitor cost after first 100 runs; abort and reduce to 2 reps if trending high |
| Some tasks fail verification on certain profiles | Sparse matrix | Record failures as data points (passed=false); analyze failure patterns as a dimension |
| Judge scores add noise at n=3 | Unreliable quality signal | Report judge scores as supplementary, not primary. Primary metrics remain static analyzers |
| Dashboard HTML becomes unwieldy with 53 tasks | Poor UX | Task grouping with collapsible sections; summary view (medians only) + detail view (full IQR) |

## 8. Out of Scope

- Other variant profiles (tdd-only, planning-only, limits-only) — not included in the matrix. Can be added later.
- Minimalism variant — already has data; included only if time permits.
- Profile auto-switching based on task type — future work after data validates the concept.
- Hook-based enforcement for hybrid — deliberately excluded per design decision.
