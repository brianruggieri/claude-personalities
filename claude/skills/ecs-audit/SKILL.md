---
name: ecs-audit
version: 1.0.0
description: |
  Bootstrap a weekly/monthly/quarterly architecture, ecosystem, and
  game-quality drift audit into any Bevy ECS plugin-per-agent project.
  Installs a portable `scripts/ecs-audit.sh`, a GitHub Actions workflow
  that auto-opens/closes a GitHub issue when findings appear, and a
  config shim tuned for the target project.
  Use when asked to "set up rolling audit", "add ecs audit", "install
  architecture drift check", or when bootstrapping a new Bevy ECS repo
  that should inherit curling-game's audit conventions.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# ECS Audit Skill

This skill installs a rolling audit into a Bevy ECS project so architectural,
ecosystem, and game-quality drift is surfaced as a GitHub issue rather than
accumulating silently.

The reference implementation lives in the curling-game repo at
`~/git/curling`. Use it as the source-of-truth for script updates — bug
fixes discovered in a downstream project should flow upstream there.

## Files this skill installs

From `~/git/curling`, copy:

- `scripts/ecs-audit.sh` → target repo
- `scripts/ecs-audit/checks-arch.sh` → target repo
- `scripts/ecs-audit/checks-docs.sh` → target repo
- `scripts/ecs-audit/checks-ecosystem.sh` → target repo
- `scripts/ecs-audit/checks-game.sh` → target repo
- `.github/workflows/rolling-audit.yml` → target repo
- Add `.ecs-audit/` to `.gitignore` (per-machine ratchet baselines)

## Per-project tuning

The orchestrator reads an optional `.ecs-audit.toml` at the repo root. When
installing in a new project, create one if the curling defaults don't match:

```toml
# Physics accuracy thresholds (only relevant if the project has a
# real_data_validation test that prints a median distance).
physics_median_target_cm = 13
physics_tolerance_cm = 1

# MCTS latency budgets in milliseconds, keyed to difficulty tiers.
mcts_easy_budget_ms = 150
mcts_medium_budget_ms = 350
mcts_hard_budget_ms = 550

# Shared-write resources — any plugin taking ResMut<X> for X in this list
# is expected to appear with an `X*` marker in the ownership table.
shared_write_resources = ["IceSurface", "SweeperStamina", "DisplaySettings"]

# GamePhase state writers — plugins allowed to call
# NextState<GamePhase>.set(GamePhase::...) outside #[cfg(test)] blocks.
gamephase_writers = ["turn", "input", "ai", "puzzle", "ui"]
```

If the target project isn't a curling variant, change these arrays to match
its actual shared resources and state authorities. The script works with
any Bevy ECS repo that has `src/<plugin>/mod.rs` and a `CLAUDE.md` with a
Plugin Ownership Quick Reference table.

## Installation procedure

When a user asks to install this audit, do the following:

1. Read the target repo's `Cargo.toml`, `src/` structure, and `CLAUDE.md` so
   you can answer the tuning questions.
2. Copy each file listed above from `~/git/curling` into the target repo,
   preserving the `scripts/ecs-audit/` subdirectory layout.
3. Mark `scripts/ecs-audit.sh` executable (`chmod +x`).
4. Write a `.ecs-audit.toml` with the defaults above, then walk through each
   value with the user if their project differs from curling-game.
5. Ensure `.ecs-audit/` is gitignored.
6. Run `scripts/ecs-audit.sh --list` to confirm the script is wired up.
7. Run `scripts/ecs-audit.sh --tier=1 --format=text` to get a baseline. This
   establishes per-machine ratchet baselines for warning-count deltas and
   surfaces any existing drift so the user can triage before committing.
8. Open a PR titled `chore(audit): install rolling ECS drift audit`.

## Update procedure

When a user says "upgrade ecs-audit" in a project that already has it:

1. Diff the local `scripts/ecs-audit*` tree against `~/git/curling`.
2. Summarize the differences.
3. Ask which to cherry-pick (upstream fixes usually do apply cleanly).

Always keep `~/git/curling` as the upstream. Bug fixes found downstream
must be ported back to curling first.

## Tier cadence

- **Tier 1** (weekly): architecture, docs, and ecosystem checks that are
  fast (<2 min) and high-signal.
- **Tier 2** (monthly): Tier 1 plus noisier checks — cargo-outdated, deny,
  machete, clippy::pedantic delta, physics accuracy, MCTS latency,
  determinism bit-exact.
- **Tier 3** (quarterly): everything plus the 4-minute AI vs AI win-rate
  regression, cargo tree duplicates, dead code.

Adjust the cron schedule in `rolling-audit.yml` if the target project has
a different release cadence.

## Alerting

The workflow opens a single GitHub issue per tier when findings appear and
edits its body on each subsequent run. A clean run closes the issue. This
keeps the audit noise bounded — at most three open issues (one per tier).
No email, no pages, no API credits.
