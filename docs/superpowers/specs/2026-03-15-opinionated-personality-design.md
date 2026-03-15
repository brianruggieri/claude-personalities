# Design: Opinionated Personality Profile

**Date:** 2026-03-15
**Branch:** `opinionated`
**Status:** Approved (brainstorm complete)

## Overview

The opinionated personality is the strict end of a tiered personality spectrum (blank → base → moderate → opinionated → paranoid). It layers strong defaults and guardrails on top of the base daily driver profile, encoding how Claude should THINK and WORK — not just what tools are available.

Built from research analysis of 5 leading Claude Code configuration repos:
- **RIPER-5** (tony/claude-code-riper-5) — phase-tracking, structured refusal, plans-on-disk
- **vincenthopf/My-Claude-Code** — knowledge maturity pipeline, context-as-public-good
- **trailofbits/claude-code-config** — philosophy imperatives, code quality thresholds, 3 enforcement layers
- **wshobson/commands** — numeric quality limits, error handling, security hardening
- **claude-simone** (Helmi/claude-simone) — fresh-context discipline, procedural TODOs, risk levels

## Architecture: Three Enforcement Layers

The opinionated profile uses three enforcement layers, inspired by Trail of Bits:

1. **CLAUDE.md** (soft) — philosophy, standards, workflow rules. Always in context. Can be overridden by strong conversational pressure.
2. **settings.json deny rules** (hard) — block reads to credential paths, block destructive commands. Enforced at permission level, no override possible.
3. **Hooks** (contextual) — PreToolUse hooks that intercept dangerous commands with actionable error messages. Exit code 2 blocks the action and tells Claude what to do instead.

## Files Modified

| File | Action | Description |
|------|--------|-------------|
| `claude/CLAUDE.md` | Integrated rewrite | ~255 lines. Merge opinions into natural sections. Single coherent voice. |
| `claude/settings.json` | Add deny + hooks | 12 deny rules, 2 PreToolUse hooks |
| `claude/skills/learnings/SKILL.md` | New file | ~55 lines. LEARNINGS.md discipline protocol. |

## CLAUDE.md Structure

Section order for the integrated rewrite:

```
## Machine Environment              (~38 lines, unchanged)
## Node.js (nvm)                    (unchanged)
## Rust (rustup)                    (unchanged)
## Python (pyenv)                   (unchanged)

## Engineering Philosophy            (~15 lines, NEW)
  9 imperatives: no speculative features, no premature abstraction,
  clarity over cleverness, justify every dependency, no phantom features,
  replace don't deprecate, verify at every level, bias toward action /
  gate on irreversibility, finish the job / don't invent scope

## Code Standards                    (~25 lines, NEW)
  ### Hard Limits
  50 lines/fn, complexity ≤8, ≤3 params, 100-char lines, absolute imports
  ### Zero Warnings Policy
  Fix or inline-ignore with justification
  ### Cleanliness
  No commented-out code, no magic numbers, no TODOs without tickets,
  comments explain WHY not WHAT
  ### Error Handling
  Fail fast, never swallow, include context, no bare except/catch

## Testing Discipline                (~10 lines, NEW)
  TDD-strict: failing test before implementation, regression test before
  bug fix, test behavior not implementation, mock boundaries not logic,
  verify tests catch failures, run suite before reporting done

## Global Preferences               (~30 lines, MODIFIED)
  Communication style replaced:
  - Terse by default, explain only when non-obvious
  - Structured output (Result/Scope/Summary/Next steps)
  - Banned words: critical, crucial, essential, significant,
    comprehensive, robust, elegant
  - Anti-rationalization: evidence before assertions
  - Review = report, don't fix

## Workflow & Planning               (~12 lines, NEW)
  1 file = proceed, 2+ files = TODO checklist, 3+ files = written plan
  No mid-implementation redesign, phase tracking (understand → plan →
  implement), git-log-first context, over-explore unfamiliar code

## Dependencies                      (~10 lines, NEW)
  Hard gate: purpose, alternatives, maintenance signals, license before
  install. Wait for approval. Prefer stdlib. Security fixes immediate.
  Pin exact versions.

## Orchestration Guide               (~16 lines, unchanged)
## Skills Reference                  (~28 lines, +1 learnings entry)

## Knowledge Persistence             (~4 lines, NEW)
  Search LEARNINGS.md before debugging, document after solving,
  invoke learnings skill for full protocol

## Security                          (~6 lines, NEW)
  Flag unsanitized input, no hardcoded secrets, audit deps,
  assume adversarial input at auth/authz boundaries,
  prefer trash over rm -rf

## Git Commits                       (unchanged)
## Git Worktrees                     (unchanged)

## Pre-Commit Checklist              (~6 lines, NEW)
  Re-read diff, run tests, run linters, check for secrets/debug/TODOs,
  confirm commit message quality

## PR Standards                      (~5 lines, NEW)
  Describe current state, banned words, test plan, one change per PR

## Claude Plans and Documentation    (unchanged)
## GitHub Operations                 (unchanged)
## Local Dev Conventions             (unchanged)

## Things to Never Do                (~12 lines, EXTENDED)
  Base list + rm -rf, sudo, push --force, reset --hard, pipe to bash,
  modify env/migrations/prod autonomously, expand scope, claim done
  without evidence
```

**Estimated total: ~255 lines**

## settings.json Changes

### Deny Rules (new)

```json
"deny": [
  "Read(~/.ssh/**)",
  "Read(~/.aws/**)",
  "Read(~/.gnupg/**)",
  "Read(~/.git-credentials)",
  "Read(~/Library/Keychains/**)",
  "Bash(rm -rf *)",
  "Bash(rm -fr *)",
  "Bash(sudo *)",
  "Bash(git push --force*)",
  "Bash(git reset --hard*)",
  "Bash(*wget*|*bash*)",
  "Bash(*curl*|*bash*)"
]
```

### Hooks (new)

```json
"hooks": {
  "PreToolUse": [
    {
      "matcher": "Bash",
      "command": "case \"$TOOL_INPUT\" in *'rm -rf'*|*'rm -fr'*) echo 'BLOCKED: Use trash or mv instead of rm -rf. Confirm with user.' >&2; exit 2;; esac"
    },
    {
      "matcher": "Bash",
      "command": "case \"$TOOL_INPUT\" in *'git push'*'main'*|*'git push'*'master'*) echo 'BLOCKED: Never push directly to main. Create a PR instead.' >&2; exit 2;; esac"
    }
  ]
}
```

## LEARNINGS Skill

New file: `claude/skills/learnings/SKILL.md` (~55 lines)

- YAML frontmatter with name, description
- Invocation triggers: stuck > 5 min, solved non-trivial issue, new debugging session
- File location: `~/.claude/LEARNINGS.md` (shared across profiles)
- Entry format: `### [STATE] Title \`tag\`` with Problem, Solution, Project, First seen, File
- State machine: DRAFT → CONFIRMED/INVALIDATED, CONFIRMED → REGRESSION
- Search protocol: grep for error messages, package names, file paths
- Promotion rule: only on genuine re-encounter

## Design Decisions

### Why integrated rewrite instead of layered append?
The base CLAUDE.md says "Explain reasoning and rationale" in Global Preferences. The opinionated profile says "Terse by default." Appending creates a contradiction where both instructions coexist. An integrated rewrite states the preference once with one voice.

### Why LEARNINGS.md as a skill instead of inline?
Philosophy bullets, thresholds, and checklists are passive rules — they apply to all work implicitly. The LEARNINGS.md system is an active protocol with a state machine, file format, search procedure, and entry lifecycle. Cramming it into 8 inline bullets loses the detail that makes it work. A skill lazy-loads the full protocol only when relevant.

### Why LEARNINGS.md at ~/.claude/ instead of in the profile?
A fix that works is a fix regardless of which personality is active. The knowledge base is shared infrastructure; the discipline rules (when and how to use it) are personality-specific. Profile switches should not lose accumulated knowledge.

### Why deny rules AND hooks?
Deny rules silently block. Hooks block with actionable guidance ("use trash instead"). Belt-and-suspenders: deny catches everything, hooks teach Claude what to do instead.

### Why 50-line function limit instead of Trail of Bits's 100?
This is the strict profile — the whole point is to be opinionated. 100 lines is a reasonable moderate default. 50 forces extraction earlier, which is the behavior we want to benchmark against the base profile (which has no limit at all).

## Token Budget

| Component | Est. Tokens | Loading |
|-----------|-------------|---------|
| CLAUDE.md (~255 lines) | ~3,500 | Always in context |
| settings.json deny + hooks | 0 | Enforced at permission/hook level |
| LEARNINGS skill (~55 lines) | ~800 | Lazy-loaded on invocation |
| **Total always-on** | **~3,500** | ~1.7% of 200K context |

The base profile is ~2,500 tokens. The opinionated profile adds ~1,000 tokens always-on — a 40% increase in CLAUDE.md size but still well under any context pressure threshold.

## Personality Tier Context

This design is the "Tier 3: Strict" entry in the personality spectrum:

| Tier | Profile | Strictness |
|------|---------|------------|
| 0 | `blank` | None — machine env only |
| 1 | `main` (base) | Light — preferences, no enforcement |
| 2 | (future) `moderate` | Medium — soft suggestions, higher thresholds |
| 3 | **`opinionated`** | **Strict — TDD, 50-line functions, zero warnings, 3 layers** |
| 4 | (future) `paranoid` | Maximum — container isolation, no auto-approve |

Future personalities can be derived by loosening specific thresholds from this design. The profiling workstream will benchmark opinionated vs. base head-to-head.

## Implementation Plan

To be generated via the writing-plans skill after spec approval. High-level:

1. Rewrite `claude/CLAUDE.md` with integrated opinion sections
2. Update `claude/settings.json` with deny rules and hooks
3. Create `claude/skills/learnings/SKILL.md`
4. Commit on `opinionated` branch
5. Verify by reading all files and checking for contradictions
