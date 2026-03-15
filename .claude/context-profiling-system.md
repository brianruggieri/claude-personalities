# Context: Personality Profiling & Benchmarking System

## What This Repo Is

`claude-personalities` manages switchable Claude Code agent personalities via git branches + symlinks. A zero-dependency bash script (`setup.sh`) symlinks profile files from this repo into `~/.claude/` and `~/`.

Profiles exist as git branches. Currently: `main` (base), `blank` (clean slate), `opinionated` (in development).

## The Problem This Workstream Solves

Different personalities have different costs. A CLAUDE.md with 160 lines of instructions costs more tokens per API call than one with 30 lines. Eight enabled plugins inject more system prompt content than zero plugins. Without measurement, profiles will bloat over time and the user won't know which personality is costing what.

The goal: build a system to measure, compare, and track the cost/performance of each personality profile, so the user can make informed decisions about what to include.

## Available Metrics Data

### ~/.claude.json (per-project stats)

Claude Code writes session metrics to `~/.claude.json` under a `projects` key, keyed by project path. Each project entry includes:

```json
{
  "lastCost": 24.08,
  "lastAPIDuration": 3476821,
  "lastAPIDurationWithoutRetries": 3476702,
  "lastToolDuration": 1022648,
  "lastDuration": 7961934,
  "lastLinesAdded": 375,
  "lastLinesRemoved": 171,
  "lastTotalInputTokens": 77294,
  "lastTotalOutputTokens": 142654,
  "lastTotalCacheCreationInputTokens": 576142,
  "lastTotalCacheReadInputTokens": 36169259,
  "lastTotalWebSearchRequests": 0,
  "lastModelUsage": {
    "claude-sonnet-4-6": {
      "inputTokens": 365,
      "outputTokens": 130494,
      "cacheReadInputTokens": 34820334,
      "cacheCreationInputTokens": 483511,
      "costUSD": 23.69
    }
  }
}
```

### ~/.claude.json (skill + tool usage)

```json
{
  "skillUsage": {
    "superpowers:brainstorming": { "usageCount": 28, "lastUsedAt": 1773584945593 }
  },
  "toolUsage": {
    "Read": { "usageCount": 1580, "lastUsedAt": 1772132646862 },
    "Bash": { "usageCount": 2699, "lastUsedAt": 1772132753411 }
  }
}
```

### Key Metrics to Compare Across Profiles

1. **System prompt size (tokens)** — The biggest cost driver. Larger CLAUDE.md + more plugins = more tokens per API call. This is measurable by counting tokens in the personality files.

2. **Cache creation vs cache read ratio** — High cache creation means the prompt isn't being efficiently reused. Different profiles may cache differently based on prompt size and structure.

3. **Cost per session** — `lastCost` from ~/.claude.json after running standardized tasks.

4. **Latency** — `lastAPIDuration` and `lastDuration` give API time and total time.

5. **Token overhead per turn** — The delta in input tokens between blank and a loaded profile, measured on identical tasks.

6. **Plugin load overhead** — Skills and plugins inject content into every system prompt. Measure the token cost of each enabled plugin.

### What's NOT Available

- Per-turn token breakdown (only session aggregates exist in ~/.claude.json)
- Real-time streaming metrics
- System prompt token count (would need to estimate from file sizes or use a tokenizer)
- Historical data (only `last*` values — previous session overwrites)

## What to Build

### Phase 1: Snapshot + Compare

A `./setup.sh profile` command (or separate script) that:
1. Reads the current profile's personality files and estimates token count
2. Reads the enabled plugins list and estimates their prompt contribution
3. Shows a summary: "This profile's estimated system prompt overhead is ~X tokens"
4. Can compare two profiles: `./setup.sh profile --compare main blank`

### Phase 2: Session Tracking

A mechanism to capture `~/.claude.json` metrics after each session and attribute them to the active profile. Options:
- A SessionEnd hook that snapshots metrics into a `_metrics/` directory
- A `./setup.sh snapshot` command the user runs manually
- Automatic capture via git hooks when switching profiles

### Phase 3: Historical Dashboard

Accumulated metrics stored per-profile that show trends over time:
- Average cost per session by profile
- Token usage distribution
- Profile size growth (are we bloating?)

## Architecture Constraints

- Zero external dependencies (bash, git, standard Unix tools)
- Metrics storage should be in the repo (gitignored `_metrics/` directory or similar)
- Token counting can be approximate (chars / 4 is a rough estimate, or use `wc -w` as proxy)
- Should integrate with existing `setup.sh` or be a companion script
- Don't modify profile content — this is observability tooling, not personality editing

## File Locations

- Repo: `~/git/claude_personalities/`
- Design spec: `docs/superpowers/specs/2026-03-15-personality-profiles-design.md`
- Setup script: `setup.sh`
- ~/.claude.json: `~/.claude.json` (user-level, contains metrics)
- Backups: `_backups/` (gitignored)

## User Preferences

- The user is on macOS with zsh
- Prefers tabs for indentation
- Wants cost-effective approaches (subagent-driven over parallel sessions)
- Uses Claude subscription (not API) for development
- Communication style: explain reasoning, don't just show code
