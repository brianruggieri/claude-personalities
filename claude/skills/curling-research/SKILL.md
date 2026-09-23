---
name: curling-research
description: Query the 12-notebook curling research library (rules, physics, sweeping, shot taxonomy, strategy, player roles, equipment, ice technician, broadcast, culture & history, game design, AI opponent design). Use when designing or implementing a feature whose grounding depends on real-world curling knowledge — physics constants, rule edge cases, broadcast UI conventions, AI opponent behavior, narration/commentary copy, equipment specs, ice tech reasoning. Locally orchestrated; uses A2A-compatible card metadata over local script transport (no HTTP/SSE).
---

# curling-research — Multi-notebook research coordinator

This skill is a local shell-script coordinator for the curling-research library. The library is **12 NotebookLM notebooks**, each owning one knowledge domain. Each notebook is described by an A2A-shaped local manifest in [`agent-cards/`](agent-cards/) so the routing metadata (skills, tags, descriptions) is portable. **The transport is local script invocation, not A2A-over-HTTP.** See [`A2A.md`](A2A.md) for the honest compatibility table.

## How to use this skill

1. **Frame the question.** What knowledge layer(s) does it depend on? (Physics? Rules? Broadcast UI? Strategy?)
2. **Pick specialists.** Read [`agent-cards/index.json`](agent-cards/index.json) and select 1–5 notebooks whose `tags`/`skills` match. Don't fan out to all 12 — wasted spend.
3. **Dispatch.** For one notebook: `scripts/ask <slug> "question"`. For many: `scripts/coordinator <slug,slug,slug> "question"` (parallel).
4. **Synthesize.** Each notebook returns a structured `Task` artifact (text + citations). You combine them into the final answer for the user.

## Routing heuristics (default coordinator policy)

| Trigger phrase or topic | Notebooks |
|---|---|
| friction, curl mechanism, deceleration, collision, scratch-guidance, restitution | `02-physics` |
| sweeping, broom, stamina, sweep effect, broomgate, brush head | `03-sweeping` |
| draw, guard, freeze, takeout, peel, raise, runback, come-around, weight, handle | `04-shot-taxonomy` |
| FGZ, five-rock, hammer, hog line, mixed doubles rules, wheelchair rules, time controls | `01-rules` |
| expected points, win probability, force rate, steal rate, blank end, hammer strategy | `05-strategy-analytics` |
| skip, lead, second, vice, third, coach, team chemistry, role-specific | `06-player-roles` |
| Ailsa Craig, granite, broom regs, slider, gripper, stabilizer, pebbler, nipper | `07-equipment` |
| pebble, ice prep, ice reading, path memory, frost, championship vs club ice, icemaker | `08-ice-technician` |
| camera angle, telestration, score-bug, mic'd team, broadcast, slow-mo replay | `09-broadcast` |
| origin, history, Stirling, Kilsyth, Schmirler, Olympic, etiquette, broomstacking, lore | `10-culture-history` |
| existing curling video games, control scheme, sports-sim patterns, golf control, bowling | `11-game-design` |
| MCTS, KR-UCT, Digital Curling, AlphaCurling, opponent modeling, difficulty calibration | `12-ai-opponent-design` |

If a question crosses ≥2 columns, dispatch all matching notebooks in parallel.

## Output format (A2A-shaped Task envelope)

Every `ask` invocation prints a single A2A v0.2-shaped Task object to stdout. `coordinator` prints one Task object per dispatched specialist as each completes (NDJSON: one JSON object per line). The coordinator does **not** merge results into a single artifact — the caller (Claude or another orchestrator) does the synthesis.

```json
{
  "id": "uuid",
  "contextId": "session-or-feature-id",
  "kind": "task",
  "status": { "state": "completed" },
  "artifacts": [
    {
      "artifactId": "uuid",
      "name": "answer",
      "parts": [{ "kind": "text", "text": "..." }]
    }
  ],
  "metadata": {
    "agent": "02-physics",
    "citations": [{ "title": "...", "url": "...", "source_id": "..." }]
  }
}
```

Note: this is a **local** envelope. The transport is process-spawn + stdout, NOT JSON-RPC over HTTP and NOT SSE. See [`A2A.md`](A2A.md) for the full compatibility table.

## Bootstrap (run once)

The 12 notebooks must exist in NotebookLM and have URL sources seeded. Run:

```bash
~/git/curling/.claude/skills/curling-research/scripts/bootstrap.sh
```

This will:
1. Create 12 notebooks via `notebooklm create "Curling Research — <name>"`
2. Extract every URL from `notebooks/*.md` and seed each notebook with `notebooklm source add`
3. Write the resulting notebook IDs into `registry.json` (gitignored — IDs are user-specific)

Use `--dry-run` first to preview; the script asks for explicit confirmation before any write operation.

## Files

| Path | Purpose |
|---|---|
| `notebooks/01-rules.md` … `notebooks/12-ai-opponent-design.md` | Source-list per domain (25 URLs each, ready to paste into NotebookLM if you skip bootstrap) |
| `agent-cards/index.json` | Local manifest registering all 13 cards (12 specialists + 1 coordinator); `format: "curling-research-local-manifest-v1"` |
| `agent-cards/<slug>.json` | Per-notebook A2A-shaped local manifest (no HTTP `url`, `streaming: false`) |
| `agent-cards/coordinator.json` | Coordinator's own card — so future remote A2A bridges have something to publish |
| `registry.json` | Local: notebook-slug → NotebookLM ID mapping (created by bootstrap, gitignored) |
| `scripts/bootstrap.sh` | One-time setup: create notebooks, seed sources |
| `scripts/ask` | Single-notebook query: `ask <slug> "question"` |
| `scripts/coordinator` | Multi-notebook fan-out: `coordinator <slugs-csv> "question"` |
| `A2A.md` | Detailed A2A protocol fit, best-use cases, and remote-deployment path |

## Orchestration: hooks + recipes + grounding-flush

NotebookLM has a 50-query/day cap. To avoid burning quota on every Edit/Write,
the skill ships three pieces that work together: a PostToolUse hook that
**logs** suggestions, a flush command that batches them into one coordinator
call, and per-task recipes with a 7-day cache. The hook never hits the network.

```
   Edit src/contracts.rs ──► research-grounding-check.sh
                              │  detects: const = value, rule ident, new pub
                              ▼
                         pending log  (~/.cache/curling-research/grounding-pending.jsonl)
                              │
                              │  (no network, no quota)
                              ▼
   user runs scripts/grounding-flush ──► dedupe vs cache  ──► coordinator (1 batched fan-out)
                                                                   │
                                                                   ▼
                                                           cache  (~/.cache/curling-research/grounding-cache.jsonl)
                                                                   │
   recipes (justify-physics-constant.sh, etc.)  ◄────────  cache_lookup [cached] / cache_put
```

| Component | Path | Purpose |
|---|---|---|
| Hook | `.claude/hooks/research-grounding-check.sh` | PostToolUse on Edit/Write to physics/ai/turn/scoring/contracts. Diff-scans for numeric constants, rule identifiers, new pub items; logs JSON suggestions to pending. **No network calls.** |
| Cache lib | `scripts/grounding-cache.sh` | Sourced by flush + recipes. `cache_lookup`, `cache_put`, `cache_purge_stale`. 7-day TTL (override via `CURLING_RESEARCH_CACHE_TTL_DAYS`). |
| Flush | `scripts/grounding-flush` | Reads pending, dedupes against cache, runs ONE coordinator per unique (slugs, query) tuple, writes one cache entry per source key. `--status`, `--dry-run`, `--clear`, `-y`. |
| Recipes | `scripts/recipes/*.sh` | Wrapper around coordinator with cache awareness. Cache hit → `[cached]` skip. Miss → coordinator + cache_put. |

### Recipes (one per common workflow)

| Recipe | Slugs | Use when |
|---|---|---|
| `recipes/justify-physics-constant.sh <name> <value> [unit]` | 02-physics, 08-ice-technician | Defending a constant against literature |
| `recipes/new-shot-type.sh "<shot>" [context]` | 04-shot-taxonomy, 02-physics, 12-ai-opponent-design | Adding a new shot type |
| `recipes/calibrate-difficulty.sh <tier>` | 12-ai-opponent-design, 06-player-roles, 05-strategy-analytics | Calibrating AI tier (easy/medium/hard/olympic) noise |
| `recipes/ui-screen.sh "<screen>" "<purpose>"` | 09-broadcast, 10-culture-history, 11-game-design | New UI/HUD screen needing broadcast/lore grounding |
| `recipes/rule-impact.sh "<rule>"` | 01-rules, 05-strategy-analytics, 11-game-design | Rule text + strategic impact citations |

### Hook slug-suggestion mapping (PostToolUse detection)

| File pattern | Suggested slugs |
|---|---|
| `src/contracts.rs` (anything physics-flavored) | `02-physics,12-ai-opponent-design` |
| `src/physics/**` | `02-physics,03-sweeping` |
| `src/ai/**` | `12-ai-opponent-design,02-physics,05-strategy-analytics` |
| `src/turn/**` | `01-rules,05-strategy-analytics` |
| `src/scoring/**` | `01-rules,05-strategy-analytics` |
| **rule identifier** match (overrides directory) | `01-rules,05-strategy-analytics` |

The hook detects three patterns in added/changed lines:
1. **Numeric constants** — `pub const FOO: f32 = 0.052;` or struct field `name: 0.052,` → key `<file>:<symbol>:<value>`
2. **Rule identifiers** — `FreeGuardZone`, `HogLineViolation`, `HammerEligibility`, `FiveRockRule`, `MixedDoubles`, `WheelchairCurling`, `NoTickRule`, `PowerPlay` → key `<file>:rule:<identifier>`
3. **New pub items** (in physics/ai/turn/scoring, not contracts) — `pub fn|struct|enum|trait|type X` → key `<file>:pub-<kind>:<ident>`

Suggestions are dedup'd by `key`; re-editing the same constant doesn't append a duplicate.

## Tier 3/4 — pre-commit gate + memory citations

Two complementary moves close the orchestration loop.

### Pre-commit grounding gate (Tier 3)

When `git commit` runs and any staged file matches `src/contracts.rs`,
`src/physics/`, `src/ai/`, `src/turn/`, or `src/scoring/`, AND the pending
log contains suggestions for those files, the hook prompts:

```
GROUNDING GATE — N ungrounded change(s) in your staged commit:
  src/contracts.rs:42  curl_coefficient: 0.048 -> 0.052
  [a] Run grounding-flush now (estimated 3 queries — 38/50 today remaining)
  [s] Skip and commit anyway (logged for /retro review)
  [c] Cancel commit (resolve, then re-commit)
```

| Component | Path | Purpose |
|---|---|---|
| Hook | `.claude/hooks/git-pre-commit-grounding.sh` | git pre-commit script (NOT a Claude Code hook). Reads pending log, intersects with staged paths, prompts `/dev/tty`. |
| Installer | `scripts/install-git-hooks.sh` | Idempotent symlink installer (`--force`, `--uninstall`). Run once explicitly. |
| Skip reporter | `scripts/grounding-skips` | Report skip patterns from `~/.cache/curling-research/skipped-grounding.jsonl` (`--by-file`, `--by-key`, `--days N`, `--json`). Surface in `/retro` to ground retroactively. |

Install once:

```bash
~/git/curling/.claude/skills/curling-research/scripts/install-git-hooks.sh
```

The hook is `exit 0` (proceed) when no relevant files are staged, the
pending log is empty, or no pending entry intersects the staged paths.
Choosing `[s] skip` appends `{ts, head_at_skip, branch, files,
suggestion_keys}` to `skipped-grounding.jsonl` — those records feed the
weekly retro for retroactive flushing.

### Memory + research cross-validation (Tier 4)

Memory entries can opt into TTL-based revalidation by adding a
`cites_research:` array to their frontmatter:

```yaml
---
name: Physics Calibration (research-cited)
type: project
cites_research:
  - recipe: justify-physics-constant
    args: "curl_coefficient 0.048"
    ttl_days: 90
    last_validated: "2026-04-27T14:00:00Z"
    answer_summary: "..."
---
```

`scripts/memory-validate` enumerates citations across the per-project
memory dir, tracks TTL, re-runs expired citations through their recipes,
and compares answers via token-set Jaccard similarity (default threshold
0.85, override via `MEMORY_VALIDATE_SIM_THRESHOLD`).

| Mode | Effect |
|---|---|
| `memory-validate` | List status (fresh / expired / never), no queries |
| `memory-validate --check <memfile>` | Run expired citations, report drift, no writes |
| `memory-validate --apply <memfile>` | Run + write new `last_validated` + `answer_summary` (atomic) |
| `memory-validate --apply-all` | Iterate all expired across the memory dir |
| `memory-validate --json` | Machine-readable status |

Recipes already use the 7-day cache, so re-running them rarely costs
quota — the memory validator amortizes onto recipe cache hits when
possible. Drift is reported with a side-by-side `stored:` vs `current:`
diff and a recommendation to either update the cited value or refresh
with `--apply`.

The seed example lives at
`~/.claude/projects/-Users-brianruggieri-git-curling/memory/project_physics_calibration_revalidated.md`.

## When NOT to use this skill

- Questions about Bevy 0.18 APIs → use `context7` (this skill is curling knowledge, not Rust)
- Questions about the in-repo physics constants → read `docs/physics-provenance.md` first; query `02-physics` only when justifying a *new* value
- Quick rule lookups during code review → the existing `rules-drift-watch` skill already wraps NotebookLM for that specific workflow

## Related skills

- `rules-drift-watch` (predecessor; covers rule-update workflow specifically)
- `physics-incident-postmortem` (consumes Physics notebook output)
- `validation-dashboard-refresh` (consumes Physics + Strategy)
- `explain-shot-choice` (consumes AI Opponent + Strategy)
