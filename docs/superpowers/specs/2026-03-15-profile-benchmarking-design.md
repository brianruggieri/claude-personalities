# Profile Benchmarking & Profiling System

**Date:** 2026-03-15
**Status:** Approved
**Author:** anonymous + Claude

## Problem

Different Claude Code personality profiles have different costs. A CLAUDE.md with 160 lines costs more tokens per API call than one with 30 lines. Eight enabled plugins inject more system prompt content than zero. Without measurement, profiles bloat over time and users can't make data-driven decisions about what to include.

As the profile library grows — potentially with community contributions — users need a way to compare profiles across cost, capabilities, and quality dimensions before choosing one.

## Goals

1. Measure and compare the static overhead of each profile (tokens, plugins, skills, capabilities)
2. Provide a capability matrix showing what each profile is equipped for
3. Design a benchmark system for measuring quality/performance (built later)
4. Support an arbitrary number of profiles with a scalable manifest convention
5. Minimal dependencies — bash, git, and python3 (ships with macOS) for JSON parsing

## Non-Goals

- Modifying profile content (this is observability tooling only)
- Real-time monitoring or dashboards
- Automatic profile optimization or recommendations
- API-level token counting (we estimate from char counts)

## Architecture

Three phases, designed together, built incrementally:

- **Phase 1 (build now):** Static profiler — manifest convention, comparison table, capability matrix, detail view
- **Phase 2 (build later):** Session snapshots — capture ~/.claude.json metrics per profile over time
- **Phase 3 (build later):** Benchmark runner — standardized tasks with automated scoring

All commands live in `setup.sh`. All metrics storage lives in `_metrics/` (gitignored).

### Dependencies

- `bash` — script execution
- `git` — branch reading via `git show` (no branch switching)
- `python3` — JSON parsing via `python3 -c "import json"` (ships with macOS, no pip packages required)

YAML is not used. All data files use JSON for reliable parsing. Benchmark task definitions (`task.json`, `prompt.md`, `verify.sh`) use JSON for structured data and plain files for content.

---

## Phase 1: Static Profiler

### Profile Manifest (`profile.json`)

Every profile branch includes a `profile.json` at the repo root:

```json
{
  "name": "main",
  "description": "Full-featured daily driver with design, testing, and development skills",
  "author": "anonymous",
  "category": "full-stack",
  "tags": ["design", "testing", "browser-automation", "code-review", "tdd"],
  "capabilities": [
    "frontend-design",
    "tdd-workflow",
    "code-review",
    "browser-testing",
    "api-docs-lookup",
    "typescript-intelligence",
    "design-polish",
    "autonomous-loops"
  ]
}
```

Fields:

| Field | Required | Purpose |
|---|---|---|
| `name` | yes | Profile identifier (matches branch name) |
| `description` | yes | One-line description for comparison table |
| `author` | yes | Who created/maintains this profile |
| `category` | yes | Controlled vocabulary for sorting/filtering |
| `tags` | no | Freeform tags for discovery |
| `capabilities` | yes | Controlled vocabulary — what this profile is equipped for |

Categories: `minimal`, `full-stack`, `frontend`, `backend`, `ops`, `specialized`

### Capability Registry (`capabilities.json`)

Lives at the repo root. The profiler **always reads this from the `main` branch** (`git show main:capabilities.json`) regardless of which branch is checked out. This avoids drift across branches — `main` is the canonical source for the capability vocabulary.

```json
{
  "frontend-design": {
    "description": "Create and refine web UI components and pages",
    "provided_by": [
      { "plugin": "frontend-design" },
      { "plugin": "impeccable" }
    ],
    "benchmark_task": "create-react-component"
  },
  "tdd-workflow": {
    "description": "Red-green-refactor test-driven development",
    "provided_by": [
      { "plugin": "superpowers", "skill": "test-driven-development" }
    ],
    "benchmark_task": "write-unit-tests"
  },
  "code-review": {
    "description": "Automated code review for pull requests",
    "provided_by": [
      { "plugin": "code-review" }
    ],
    "benchmark_task": "review-code-diff"
  },
  "browser-testing": {
    "description": "Headless browser automation for QA and testing",
    "provided_by": [
      { "plugin": "playwright" }
    ],
    "benchmark_task": null
  },
  "api-docs-lookup": {
    "description": "Up-to-date library documentation lookup",
    "provided_by": [
      { "plugin": "context7" }
    ],
    "benchmark_task": null
  },
  "typescript-intelligence": {
    "description": "TypeScript/JavaScript language server for code intelligence",
    "provided_by": [
      { "plugin": "typescript-lsp" }
    ],
    "benchmark_task": null
  },
  "design-polish": {
    "description": "Design quality review, polish, and normalization",
    "provided_by": [
      { "plugin": "impeccable" }
    ],
    "benchmark_task": null
  },
  "autonomous-loops": {
    "description": "Continuous iterative development loops",
    "provided_by": [
      { "plugin": "ralph-loop" }
    ],
    "benchmark_task": null
  }
}
```

The three-way link (capability → provider → benchmark_task) ensures that when a benchmark task is added later, the profiler automatically surfaces results for the corresponding capability.

### Plugin Metadata Registry (`plugin-metadata.json`)

MCP tool counts and skill counts cannot be reliably discovered from the plugin cache at rest (MCP servers must be running to enumerate their tools). Instead, the profiler uses a manually maintained metadata registry:

```json
{
  "superpowers": {
    "marketplace": "claude-plugins-official",
    "skills": 22,
    "mcp_tools": 0,
    "listing_tokens": 880,
    "description": "Core skills: TDD, debugging, collaboration patterns"
  },
  "impeccable": {
    "marketplace": "impeccable",
    "skills": 18,
    "mcp_tools": 0,
    "listing_tokens": 720,
    "description": "Design vocabulary: polish, distill, audit, bolder, quieter"
  },
  "playwright": {
    "marketplace": "claude-plugins-official",
    "skills": 0,
    "mcp_tools": 25,
    "listing_tokens": 500,
    "description": "Browser automation and testing"
  },
  "context7": {
    "marketplace": "claude-plugins-official",
    "skills": 0,
    "mcp_tools": 2,
    "listing_tokens": 40,
    "description": "Library documentation lookup"
  },
  "code-review": {
    "marketplace": "claude-plugins-official",
    "skills": 1,
    "mcp_tools": 0,
    "listing_tokens": 40,
    "description": "PR code review"
  },
  "ralph-loop": {
    "marketplace": "claude-plugins-official",
    "skills": 3,
    "mcp_tools": 0,
    "listing_tokens": 120,
    "description": "Autonomous iterative loops"
  },
  "frontend-design": {
    "marketplace": "claude-plugins-official",
    "skills": 1,
    "mcp_tools": 0,
    "listing_tokens": 40,
    "description": "Frontend design skill"
  },
  "typescript-lsp": {
    "marketplace": "claude-plugins-official",
    "skills": 0,
    "mcp_tools": 0,
    "lsp_servers": 1,
    "listing_tokens": 20,
    "description": "TypeScript language server"
  }
}
```

This file lives at the repo root and is shared across branches. Updated manually when plugins are added/removed/updated. The `listing_tokens` field is the estimated per-turn overhead from having that plugin's skills and tools listed in the system prompt (not the full skill content, which is loaded on-demand).

**Plugin cache path convention:** Enabled plugins in `settings.json` use the format `name@marketplace` (e.g., `superpowers@claude-plugins-official`). The cache path is `~/.claude/plugins/cache/<marketplace>/<name>/<version>/`. The profiler uses `plugin-metadata.json` instead of querying the cache directly.

### Base Overhead Reference (`benchmarks/base-overhead.json`)

Piebald-AI/claude-code-system-prompts provides exact token counts for Claude Code's internal system prompt fragments. We maintain a version-pinned copy as a reference constant:

```json
{
  "claude_code_version": "2.1.76",
  "source": "https://github.com/Piebald-AI/claude-code-system-prompts",
  "last_updated": "2026-03-15",
  "base_tokens": {
    "system_prompt_fragments": 3000,
    "tool_descriptions": 8500,
    "misc_overhead": 1500,
    "total": 13000
  },
  "notes": "Tokens Claude Code injects regardless of profile configuration. Profile overhead is additive. Update when Claude Code releases a new version with significant prompt changes."
}
```

### Pricing Reference (`benchmarks/pricing.json`)

Pricing constants live in a data file rather than hardcoded in the script, making updates a data change:

```json
{
  "last_updated": "2026-03-15",
  "source": "https://platform.claude.com/docs/en/about-claude/pricing",
  "models": {
    "opus-4.6": {
      "cache_read_per_mtok": 0.50,
      "cache_miss_per_mtok": 5.00,
      "output_per_mtok": 25.00
    },
    "sonnet-4.6": {
      "cache_read_per_mtok": 0.30,
      "cache_miss_per_mtok": 3.00,
      "output_per_mtok": 15.00
    },
    "haiku-4.5": {
      "cache_read_per_mtok": 0.10,
      "cache_miss_per_mtok": 1.00,
      "output_per_mtok": 5.00
    }
  },
  "default_model": "opus-4.6"
}
```

### Commands

#### `./setup.sh profile` — Comparison Table

Reads all local branches via `git show` (no branch switching). For each branch:

1. `git show <branch>:profile.json` → metadata, category, capabilities
2. `git show <branch>:claude/CLAUDE.md` → char count → tokens (chars / 4)
3. `git show <branch>:claude/settings.json` → parse `enabledPlugins` via python3 json module → count
4. For each enabled plugin, look up `plugin-metadata.json` → skill count, MCP tool count, listing tokens
5. `git show <branch>:claude/MEMORY.md` → char count → tokens
6. Cross-reference capabilities against `capabilities.json` (always read from `main` branch)

**Graceful degradation:** If any file is missing on a branch (`profile.json`, `MEMORY.md`, `settings.json`, `claude/CLAUDE.md`), the profiler treats that component's contribution as 0 and continues. A missing `profile.json` results in category shown as "unknown" and capabilities as "undeclared". A missing `CLAUDE.md` results in 0 profile instruction tokens.

Output:

```
Claude Personalities — Profile Comparison
══════════════════════════════════════════════════════════════════════════════════

Profile        Category     Tokens†  Plugins  Skills  MCP Tools  User Skills
────────────────────────────────────────────────────────────────────────────────
blank          minimal       2,350      0       0         0          0
main           full-stack    5,500      8      45        27         11
opinionated    full-stack    5,800      8      45        27         11

† Estimated per-turn system prompt overhead (chars / 4). Does not include
  Claude Code base overhead (~13,000 tokens shared by all profiles).

Capability Matrix
────────────────────────────────────────────────────────────────────────────────
                        blank    main    opinionated
Frontend design           —       ✓          ✓
TDD workflow              —       ✓          ✓
Code review               —       ✓          ✓
Browser testing           —       ✓          ✓
API docs lookup           —       ✓          ✓
TypeScript LSP            —       ✓          ✓
Design polish             —       ✓          ✓
Autonomous loops          —       ✓          ✗
```

**Scalability note:** The profiler runs multiple `git show` commands per branch (profile.json, CLAUDE.md, settings.json, MEMORY.md). With 20 profiles this is ~80 git operations, with 50 profiles ~200. This is acceptable for local repos but if performance becomes noticeable, results can be cached in `_metrics/`.

#### `./setup.sh profile --detail <branch>` — Token Breakdown

```
Profile: main (full-stack)
"Full-featured daily driver with design, testing, and development skills"
Author: anonymous
══════════════════════════════════════════════════════════════════════════════════

Token Breakdown (estimated per-turn overhead)
────────────────────────────────────────────────────────────────────────────────
  CLAUDE.md                           2,137 tokens   ██████████████░░░░░░  39%
  Skill listings (45 skills)          1,875 tokens   ███████████░░░░░░░░░  34%
  MCP tool declarations (27 tools)      675 tokens   ████░░░░░░░░░░░░░░░  12%
  MEMORY.md                             222 tokens   █░░░░░░░░░░░░░░░░░░   4%
  settings.json                         414 tokens   ██░░░░░░░░░░░░░░░░░   8%
  Other (keybindings, hooks)            177 tokens   █░░░░░░░░░░░░░░░░░░   3%
  ─────────────────────────────────────────────────────────────────────────────
  TOTAL (profile overhead)            5,500 tokens
  + Base CC overhead                 13,000 tokens
  = Estimated total prompt           18,500 tokens

Cost Estimate (per-turn, Opus 4.6 cache-read rates)
────────────────────────────────────────────────────────────────────────────────
  Per turn (cache hit):     $0.0028
  Per turn (cache miss):    $0.0275
  Delta vs blank:           $0.0016/turn
  100-turn session delta:   ~$0.16 more than blank

Plugins (8 enabled)
────────────────────────────────────────────────────────────────────────────────
  superpowers          22 skills    0 MCP tools   ~880 listing tokens
  impeccable           18 skills    0 MCP tools   ~720 listing tokens
  playwright            0 skills   25 MCP tools   ~500 listing tokens
  context7              0 skills    2 MCP tools    ~40 listing tokens
  code-review           1 skill     0 MCP tools    ~40 listing tokens
  ralph-loop            3 skills    0 MCP tools   ~120 listing tokens
  frontend-design       1 skill     0 MCP tools    ~40 listing tokens
  typescript-lsp        0 skills    1 LSP server   ~20 listing tokens

User Skills (11)
────────────────────────────────────────────────────────────────────────────────
  browse, exa-search, gstack-upgrade, plan-ceo-review, plan-eng-review,
  qa, retro, review, setup-browser-cookies, ship, gstack

  Note: User skills are custom skill files in claude/skills/. They contribute
  to the skill listing overhead in the system prompt.

Capabilities (7/8 declared)
────────────────────────────────────────────────────────────────────────────────
  ✓ frontend-design, tdd-workflow, code-review, browser-testing,
    api-docs-lookup, typescript-intelligence, design-polish
  ✗ autonomous-loops (missing provider: ralph-loop skill)
```

#### `./setup.sh profile --compare <a> <b>` — Side-by-Side Diff

Both branch names are required.

```
Comparing: main vs blank
══════════════════════════════════════════════════════════════════════════════════

                            main         blank        delta
────────────────────────────────────────────────────────────────────────────────
Estimated tokens            5,500        2,350       +3,150
Plugins                         8            0           +8
Skills                         45            0          +45
MCP tools                      27            0          +27
Cost/turn (cache hit)      $0.0028      $0.0012     +$0.0016
Cost/100 turns             $0.28        $0.12       +$0.16

Capabilities only in main:
  + frontend-design, tdd-workflow, code-review, browser-testing,
    api-docs-lookup, typescript-intelligence, design-polish

Capabilities only in blank:
  (none)
```

### Token Estimation Method

Token counts are estimated as `character_count / 4`. This is a standard approximation for English text with code. It is not exact — actual tokenization depends on the model's tokenizer — but it is:

- Consistent across profiles (fair for comparison)
- Zero-dependency (no external tokenizer needed)
- Within ~10-15% of actual token counts for mixed English/code content

Sources of characters counted:
- `claude/CLAUDE.md` — full file content
- `claude/settings.json` — full file content (includes permissions, hooks, env vars)
- `claude/MEMORY.md` — full file content
- Plugin skill/tool listings — from `plugin-metadata.json` `listing_tokens` field (these represent the "skill listing" overhead — the name + description lines injected into the system-reminder, not the full skill body which is loaded on-demand via the Skill tool)
- User skills — estimated at ~40 chars per skill directory entry in `claude/skills/`

### Cost Estimation Model

Uses published Anthropic pricing from `benchmarks/pricing.json`. Default display uses Opus 4.6 cache-read rates (the most common case during normal usage). The `--detail` view shows both cache-hit and cache-miss costs.

---

## Phase 2: Session Snapshots (Designed, Build Later)

### `./setup.sh snapshot`

Captures `~/.claude.json` metrics and attributes them to the active profile:

1. Reads current branch → profile name
2. Reads `~/.claude.json` → extracts the project entry for the current working directory
3. Creates `_metrics/sessions/<profile>/` if it doesn't exist
4. Writes timestamped JSON to `_metrics/sessions/<profile>/<timestamp>.json`

Captured fields:
- `profile`, `timestamp`, `project` (path)
- `cost_usd`, `duration_seconds`, `api_duration_seconds`
- `total_input_tokens`, `total_output_tokens`
- `cache_creation_tokens`, `cache_read_tokens`, `cache_hit_rate`
- `lines_added`, `lines_removed`
- `model_usage` (per-model breakdown)

### Optional SessionEnd Hook

Opt-in automatic capture via `settings.json`:

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "type": "command",
        "command": "/path/to/claude_personalities/setup.sh snapshot --quiet"
      }
    ]
  }
}
```

Not included in any profile by default. Documented for users who want hands-free capture.

### Enriched Profile Output

When session data exists, `./setup.sh profile` appends session averages:

```
Session Averages (from _metrics/sessions/)
────────────────────────────────────────────────────────────────────────────────
Profile     Sessions  Avg Cost  Avg Duration  Avg Cache Hit%
main            12     $8.42      22m 15s        97.2%
blank            3     $3.15       9m 40s        94.8%
```

---

## Phase 3: Benchmark System (Designed, Build Later)

### Benchmark Task Structure

Tasks live in `benchmarks/tasks/` at the repo root (shared across all branches). Tasks are auto-discovered by globbing `benchmarks/tasks/*/task.json`:

```
benchmarks/
  base-overhead.json
  pricing.json
  tasks/
    hello-world/
      task.json
      prompt.md
      verify.sh
      expected/
    fix-python-bug/
      task.json
      prompt.md
      verify.sh
      fixture/
    create-react-component/
      task.json
      prompt.md
      verify.sh
      fixture/
    write-unit-tests/
      task.json
      prompt.md
      verify.sh
      fixture/
    review-code-diff/
      task.json
      prompt.md
      verify.sh
      fixture/
```

### Task Definition (`task.json`)

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

Fields:

| Field | Values | Purpose |
|---|---|---|
| `category` | `baseline`, `coding`, `debugging`, `testing`, `frontend`, `review` | Task classification |
| `capability` | key from `capabilities.json` | Links task to capability matrix |
| `difficulty` | `basic`, `intermediate`, `advanced` | Expected complexity |
| `scoring` | `binary`, `graded` | Pass/fail or 0-100 score |
| `metrics` | array | Which metrics to capture |

### Benchmark Runner (`./setup.sh benchmark`)

Execution flow:

1. Create a temp working directory
2. Copy `fixture/` files into it (if present)
3. Run: `claude --print --prompt "$(cat prompt.md)" --cwd $tmpdir`
4. Run: `verify.sh` against the working directory
5. Capture `~/.claude.json` metrics
6. Store results in `_metrics/benchmarks/<profile>/<task>/<timestamp>.json`
7. Clean up temp directory

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

When multiple runs exist for a task, the profiler compares the latest run against the historical average. A >10% cost increase or a pass→fail transition triggers a warning:

```
⚠ Regression: "fix-python-bug" on main
  Previous avg cost: $0.42 → Current: $0.58 (+38%)
  Possible cause: CLAUDE.md grew by 1,200 tokens since last benchmark
```

### Starter Benchmark Suite

| Task | Category | Capability Tested | Why It Differentiates |
|---|---|---|---|
| `hello-world` | baseline | (none) | Every profile should pass; measures pure cost overhead |
| `fix-python-bug` | debugging | tdd-workflow | Tests if debugging/TDD skills reduce time and cost |
| `create-react-component` | frontend | frontend-design | Tests frontend-design / impeccable value |
| `write-unit-tests` | testing | tdd-workflow | Tests TDD workflow skill value |
| `review-code-diff` | review | code-review | Tests code-review plugin value |

### Design Constraints

- Benchmarks are expensive (real Claude sessions) — always opt-in, never automatic
- LLM output is non-deterministic — multiple runs needed for statistical validity; report shows run count and variance
- Tasks must be self-contained — no network access, no external dependencies, fixture provides everything
- `benchmarks/` lives on all branches (shared infrastructure, not profile content)

---

## Directory Structure

```
claude_personalities/
  setup.sh                          # all commands
  profile.json                      # per-branch manifest
  capabilities.json                 # shared capability vocabulary (canonical on main)
  plugin-metadata.json              # manually maintained plugin stats
  benchmarks/                       # shared across all branches
    base-overhead.json              # Piebald-sourced base token counts
    pricing.json                    # Anthropic pricing constants
    tasks/                          # (Phase 3 — task dirs added later)
  _metrics/                         # gitignored, created on first use by setup.sh
    sessions/                       # Phase 2 — session snapshots
    benchmarks/                     # Phase 3 — benchmark results
    regressions.log                 # Phase 3 — flagged regressions
  claude/                           # profile content (per-branch)
  home/                             # profile content (per-branch)
```

## Command Summary

| Command | Phase | Description |
|---|---|---|
| `./setup.sh profile` | 1 | Comparison table + capability matrix |
| `./setup.sh profile --detail <branch>` | 1 | Token breakdown, cost estimate, plugin inventory |
| `./setup.sh profile --compare <a> <b>` | 1 | Side-by-side delta between two profiles |
| `./setup.sh snapshot` | 2 | Capture current session metrics |
| `./setup.sh benchmark` | 3 | Run all benchmark tasks against current profile |
| `./setup.sh benchmark --task <name>` | 3 | Run a specific benchmark task |
| `./setup.sh benchmark --report` | 3 | Show benchmark results across profiles |

## Implementation Scope

**Build now (Phase 1):**
- `profile.json` for each existing branch (main, blank, opinionated)
- `capabilities.json` at repo root
- `plugin-metadata.json` at repo root
- `benchmarks/base-overhead.json`
- `benchmarks/pricing.json`
- `./setup.sh profile` command (table, detail, compare modes)
- Update `./setup.sh` usage text with new commands

**Design only (Phase 2-3):**
- `./setup.sh snapshot` command
- SessionEnd hook documentation
- `./setup.sh benchmark` runner
- 5 starter benchmark tasks
- Regression detection

## References

- [Piebald-AI/claude-code-system-prompts](https://github.com/Piebald-AI/claude-code-system-prompts) — Base overhead token counts
- [Claude Code Cost Docs](https://code.claude.com/docs/en/costs) — Official cost guidance
- [Anthropic Pricing](https://platform.claude.com/docs/en/about-claude/pricing) — Cache read/write rates
- [claude-flow Benchmarking](https://github.com/ruvnet/ruflo/wiki/Performance-Benchmarking) — Benchmark methodology patterns
