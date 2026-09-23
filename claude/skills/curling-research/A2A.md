# A2A wiring — curling-research

This skill is a **local shell-script coordinator** that uses A2A's *data shapes* (Agent Cards, Task envelopes, Artifact/Parts structure) for portability. **It is not a compliant A2A transport.** There is no HTTP server, no SSE, no `/.well-known/agent-card.json`, and no JSON-RPC endpoint. Specialist invocation happens by spawning local processes and reading NDJSON from stdout.

We picked this framing on purpose: NotebookLM is the source-of-truth backend, and the shell scripts are a thin adapter. Adopting the A2A *envelope shapes* means a future remote deployment is a transport-only change, while staying honest about what runs today.

## Compatibility status — what's real and what's aspirational

| Field / capability                       | Local implementation                                              |
|------------------------------------------|-------------------------------------------------------------------|
| Agent Card JSON shape (name/desc/skills) | Honored — used to drive routing                                   |
| `protocolVersion: 0.2.0`                 | Recorded for portability; no client validates it                  |
| `url`                                    | Set to `null` — there is no HTTP endpoint                         |
| `provider.url`                           | Set to `null` — provider is a local skill directory               |
| `capabilities.streaming`                 | `false` — `ask` is synchronous; `coordinator` emits NDJSON locally |
| `capabilities.pushNotifications`         | `false` — not implemented                                         |
| `securitySchemes`                        | Empty — local-only invocation, no auth surface                    |
| `defaultInputModes` / `defaultOutputModes` | Honored on input; output is NDJSON-wrapped text + JSON           |
| `skills[]`                               | Honored — coordinator routes by `tags`                            |
| `tasks/send` JSON-RPC                    | Not implemented; `scripts/ask` is the local equivalent            |
| `tasks/sendSubscribe` (SSE)              | Not implemented; `scripts/coordinator` emits NDJSON to stdout     |
| `tasks/get`, `tasks/cancel`              | Not implemented                                                   |
| `x-curlingResearch.*` extensions         | Local-only — `notebookId`, `transport`, `skillDir`, etc.          |

The Agent Cards in `agent-cards/` are **A2A-shaped local manifests**, not A2A-compliant Agent Cards a remote client could resolve. `agent-cards/index.json` is a bespoke registry document with `format: "curling-research-local-manifest-v1"`.

## Rate limits and throttling

NotebookLM's free tier (verified 2026) has hard caps the skill must respect:

| Limit | Value | Scope |
|---|---|---|
| Chat queries / day | 50 | account-wide, resets at 00:00 UTC |
| Sources / notebook | 50 | per notebook (separate quota; not affected by `ask`/`coordinator`) |
| Burst rate | ~2 simultaneous asks before throttling kicks in | account-wide |

We've observed real throttling at burst >2: a coordinator fan-out of 2 in true parallel can have one fail. The defaults below were chosen to stay safely inside that envelope while still feeling live in interactive use.

**Skill defaults:**

| Knob | Default | Env override | Purpose |
|---|---|---|---|
| `STAGGER_MS` | `1200` (~0.83 req/s) | `CURLING_RESEARCH_STAGGER_MS` | Spacing between coordinator child launches |
| `MAX_CONCURRENT` | `2` | `CURLING_RESEARCH_MAX_CONCURRENT` | Concurrency cap inside coordinator |
| `QUOTA_LOG` | `~/.cache/curling-research/queries.jsonl` | `CURLING_RESEARCH_QUOTA_LOG` | Where per-query records go |

Both `scripts/ask` (in `--json` mode) and `scripts/coordinator` (per child launch) append a JSONL record to the quota log; `ask` and `coordinator` emit a stderr **note / WARN / ERROR** line at 30 / 45 / 50 queries used today (account-wide). Warnings never block a query — the script will still run when you cross 50/day, and you'll see whatever NotebookLM does (typically an error from `notebooklm ask`).

**`scripts/quota`** prints today's usage broken down by notebook:

```bash
scripts/quota                  # today (UTC) summary + per-notebook breakdown
scripts/quota --week           # trailing 7-day rolling view
scripts/quota --reset-warning  # silence stderr threshold notes for the rest of today
```

**Plus tier upgrade path.** If you regularly need more than 50 queries/day, **Google AI Plus** (paid; $19.99/mo USD as of 2025; verify the latest cost on the upgrade page if you suspect it's shifted) raises the chat-query and source caps. The skill code does not change — same scripts, same JSON, same `notebooklm ask` invocation — only the daily ceiling moves. If you upgrade, raise the threshold env vars to silence the free-tier note/warn lines:

```bash
export CURLING_RESEARCH_STAGGER_MS=400      # tighter stagger if Plus burst is more generous
export CURLING_RESEARCH_MAX_CONCURRENT=4    # raise as burst capacity allows
```

## Why use A2A's data shapes anyway

1. **Portability of the envelope.** A future remote deployment can re-emit the same Task/Artifact/Parts JSON over HTTP+SSE without rewriting any per-notebook adapter logic.
2. **Shared vocabulary.** "Agent Card", "skill", "tag", "Task artifact", "citations" are recognized concepts; using them for the local manifest means future readers (Codex, Gemini, MCP bridges) onboard faster than to a fully-bespoke schema.
3. **Cheap upgrade path.** The transport is what changes when going remote — not the data model.

## What we implement vs. defer

| A2A primitive                                   | Local implementation                                                | Deferred                            |
|-------------------------------------------------|---------------------------------------------------------------------|-------------------------------------|
| Agent Card data shape (`agent-cards/<slug>.json`) | A2A-shaped local manifest (no HTTP `url`, no `securitySchemes`)   | Spec compliance for remote clients  |
| Synchronous query (`tasks/send` analog)         | `scripts/ask` — local process, prints one Task envelope to stdout  | HTTP+JSON-RPC transport             |
| Streaming query (`tasks/sendSubscribe` analog)  | `scripts/coordinator` — emits one NDJSON envelope per specialist as each completes (local stdout, NOT SSE) | HTTP+SSE transport                  |
| `tasks/get`, `tasks/cancel`                     | Not implemented                                                     | Full task store                     |
| Authentication (`securitySchemes`)              | None — local-only invocation                                        | OAuth/PAT for remote                |
| Push notifications                              | Not implemented                                                     | —                                   |

The coordinator does **not** merge specialist results into a single artifact — it emits one envelope per specialist as they finish. The caller (Claude or another orchestrator) does the synthesis.

## Best use cases

### 1. Cross-domain feature design
**Trigger:** "How should sweeping affect a come-around draw?"

```bash
scripts/coordinator "02-physics,03-sweeping,04-shot-taxonomy,05-strategy-analytics" \
  "Quantify sweeping's effect on a come-around draw: distance gain, curl reduction, optimal timing, and the strategic when-to-sweep question."
```

The coordinator dispatches 4 notebooks in parallel and emits 4 NDJSON envelopes (one per specialist, each with its own citations) as they complete. Claude (or whichever caller) synthesizes the unified answer.

### 2. Implementation grounding for `contracts.rs` changes
**Trigger:** "Proposing curl_coefficient = 0.052 — justified?"

```bash
scripts/coordinator "02-physics,12-ai-opponent-design" \
  "Calibrated curl coefficient values from CSAS+CurlR data: what range does the literature support, and how sensitive is MCTS shot selection to this constant?"
```

### 3. Rule-drift verification
**Trigger:** "WCF announced a tick-shot rule change for mixed doubles 2026."

Already covered by the dedicated `rules-drift-watch` skill, but multi-domain impact analysis routes through:

```bash
scripts/coordinator "01-rules,05-strategy-analytics,11-game-design" \
  "Mixed doubles 2026 tick-shot rule change: what changes legally, how does it shift strategy, and which existing curling games modeled the prior rule?"
```

### 4. Authentic UI / narration / commentary copy
**Trigger:** Writing scoreboard tooltips, end-break narration, AI commentary lines.

```bash
scripts/coordinator "09-broadcast,10-culture-history" \
  "Write 6 broadcast-grade narration lines for a steal of three in the 8th end. Vocabulary should match Vic Rauter / Mike Harris register; reference the Spirit of Curling without cliché."
```

### 5. Cross-tool interop (data shape only)

The cards in `agent-cards/` are A2A-*shaped* local manifests. Any consumer that reads Agent Card JSON for routing metadata (skills, tags, descriptions) can ingest them; consumers that try to resolve `url` or call `tasks/send` over HTTP will find nothing to talk to. To be invoked from Codex, Gemini agents, LangGraph, or an MCP bridge, the consumer must shell out to `scripts/ask` / `scripts/coordinator` locally — or someone has to stand up the remote A2A server (see "Upgrade path" below).

## Routing strategy

The coordinator's routing logic is **keyword + tag match**, not LLM-based, by default — it's cheap, deterministic, and good enough.

For ambiguous queries, fall back to **Claude as router**: read `agent-cards/index.json` into context, ask Claude which notebooks apply, then dispatch. This is the natural mode when the skill is invoked inside a Claude session.

```text
User question
   │
   ├─ keyword/tag match → 1+ notebook slugs
   │     │
   │     └─ scripts/coordinator <slugs> "question"
   │
   └─ ambiguous? → Claude reads index.json, picks slugs, then dispatches
```

## Anti-patterns

| Don't | Why |
|---|---|
| Fan out to all 12 notebooks for every question | ~13× the spend; signal-to-noise drops; NotebookLM rate-limits compound |
| Try to make NotebookLM speak A2A natively | NotebookLM is the source-of-truth backend; the **adapter** is what speaks the data shape |
| Run an HTTP A2A server before a non-Claude consumer needs it | YAGNI; NDJSON-over-stdout is sufficient for the in-session pattern |
| Hard-code notebook IDs into the per-card JSON files in git | IDs are per-account; `registry.json` is the source of truth (gitignored), and the build script injects them into `x-curlingResearch.notebookId` at card-generation time |
| Treat coordinator output as ground truth | Each Task carries citations; verify the cited URLs before encoding into `contracts.rs`, `physics-provenance.md`, or other authoritative files |
| Claim the cards are A2A-compliant | They're A2A-shaped *local manifests*. The `url` field is `null`, there is no HTTP transport, and `streaming: false` is honest. |

## Upgrade path → remote A2A server (NOT IMPLEMENTED)

When a non-Claude agent needs to consume the library remotely, the work is:

1. Wrap `scripts/ask` and `scripts/coordinator` behind a FastAPI app with two endpoints: `POST /tasks/send` and `POST /tasks/sendSubscribe`.
2. Convert NDJSON output to SSE events.
3. Publish each Agent Card at `/.well-known/agent-card.json` (one card per service URL, or one-card-with-skills-array). Replace `null` `url` / `provider.url` with the public service URL.
4. Flip `capabilities.streaming` to `true` (now backed by real SSE).
5. Add `securitySchemes` (PAT or OAuth) to each Agent Card.
6. The coordinator's Agent Card advertises the public URL.

The local-first design means **none of the per-notebook adapter code changes** — only the transport. None of this is implemented today.

## Maintenance

- When a notebook's scope drifts (e.g. you add Section 13 on parasports curling): update the source MD, the Agent Card's `skills[]` and `tags[]`, and re-run `python3 scripts/build-cards.py` (or `bootstrap.sh --refresh-card <slug>` if it exists in your version).
- When NotebookLM source IDs go stale: `notebooklm source list <notebook-id>` then `notebooklm source refresh <source-id>`.
- When you add a 13th notebook: add a row to `index.json`, add the routing row in `SKILL.md`, and re-run `python3 scripts/build-cards.py`.
