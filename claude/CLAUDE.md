# User-Level CLAUDE.md — Anonymous

## Machine Environment

- **OS:** macOS
- **Shell:** zsh with oh-my-zsh (`~/.zshrc`)
- **Editor:** Zed
- **Repos:** `~/git/`

## Node.js (nvm)

This machine uses nvm. Before running any npm/node/npx commands, activate nvm first:

```bash
source ~/.nvm/nvm.sh && nvm use
```

If a project has `.nvmrc`, `nvm use` picks it up automatically. Otherwise default is Node 22.

## Rust (rustup)

Rust is installed via rustup at `~/.cargo/bin`. The cargo/rustc binaries are not on the default PATH in non-interactive shells. When running Rust tooling:

```bash
source "$HOME/.cargo/env"
```

## Python (pyenv)

pyenv is installed but may not have Python versions configured yet. Check with:

```bash
export PATH="$HOME/.pyenv/bin:$HOME/.pyenv/shims:$PATH"
eval "$(pyenv init -)"
pyenv versions
```

If no versions are installed, prompt me before installing one.

## Global Preferences

- **Indentation:** Tabs (defer to project config if it specifies otherwise)
- **Package manager:** npm
- **Commit style:** Brief imperative sentences ("Add login page", "Fix null check in parser")
- **After code changes:** Auto-run the project's test suite to verify nothing broke
- **Communication style:** Explain reasoning and rationale, don't just show the code
- **Execution options:** When a skill offers execution choices (e.g. subagent-driven vs. parallel session), always pick the most cost-effective option without asking. Prefer subagent-driven development in the current session over spawning separate sessions.
- **Claude usage:** Use Claude subscription (Claude Code) for development work. Reserve API usage for when subscription-based tools are not practical (e.g., embedded in apps, custom integrations, production services).

## When to Ask vs. Proceed

If uncertain about intent, scope, or the right approach — ask before acting. For destructive or hard-to-reverse actions (deleting files, force-pushing, dropping data, modifying CI/CD), always confirm first regardless of confidence.

## Orchestration Guide (updated 2026-07-04 from Feb–Jul 2026 corpus review)

**Default pipeline (BKM) for a bounded feature:** workspace per feature (Orca workspace `~/orca/workspaces/<repo>/<feature>`, or worktree for programmatic parallelism) → `/brainstorm` + `/write-plan` → codex review loop on spec/plan until green → subagent-driven development (fresh implementer + reviewer per task) → cross-model review on the final PR (codex + security) → human merge. Do not invent a new orchestration shape per project — pick from the menu below. Never rebuild an orchestration framework from scratch; check the stalled-projects ledger in memory for a resume point first.

| Mechanism | Use When | Avoid When |
|-----------|----------|------------|
| **Task agents** (Agent tool, in-session) | 3+ independent subtasks; research/review fan-out; the default for delegated implementation | Flat fan-out without dependency analysis (run /tiered-fanout first) |
| **Agent Teams** (native) | Greenfield build from a locked spec with a blockedBy task graph (validated 2x) | Iterative/grind work or long background jobs — use serial subagents with orchestrator-owned gate instead |
| **Tiered epic fan-out** (`/tiered-fanout`) | Multi-issue epics, cleanup passes, 3+ parallel plans | Never a flat N-way run — shared contracts serialize |
| **Handoff docs** (`/handoff`) | Continuing multi-session work where the plan leaves decisions open (A/B-measured 41-70% token win) | Fully prescriptive plans — measured +27% pure overhead; launch with the plan alone |
| **ralph-loop / unattended** | Mechanically verifiable completion ONLY (tests, pixel-diff threshold, promise token — never vision scores); run preflight first: pinned model, fresh auth (`claude setup-token` → CLAUDE_CODE_OAUTH_TOKEN), pre-authorized permissions, disk-first outputs, one CPU-heavy job at a time | Subjective exit criteria; anything unpreflighted |
| **Superpowers skills** | Structured SDLC for new feature work | Quick ad-hoc changes |

**Hard rules (each cost a recovery session):**
- Before dispatching parallel agents, map shared function signatures/contracts/CSS surfaces — anything shared serializes or gets a lead-owned foundation commit first. Green-in-isolation ≠ compatible-when-merged.
- Orchestrator owns completion: poll and resume workers (Monitor/SendMessage); never trust self-resume of background jobs.
- Every subagent writes its deliverable to disk before returning (rate limits lose summaries, never files).
- Every non-trivial PR gets at least one different-model-family review; same-family reviewers anchor on the author's framing. All LLM grading uses a written rubric with binary per-criterion verdicts — never 1-10 scores.
- Model tiers: mechanical loops = haiku/sonnet; judgment (plan/integration review, brainstorms) = opus; second opinion = codex; unattended agents = pinned opus.

**Deprecated patterns — do not resurrect from old handoff docs/memories:** hook-enforced team choreography (Formation — zero measured quality gain), worktree symlink hooks (tracked `.claude/` + native worktree config won), claude-flow, manual polling loops (native Monitor covers it), Sculptor workspaces (dropped for Forgejo pipeline + Orca).

## Skills Reference

Invoke these explicitly when the use case matches. Most are not auto-triggered.

| Skill | Invoke When |
|-------|-------------|
| `/frontend-design` | Any web UI, component, or page work — invoke before writing code |
| `/audit`, `/polish`, `/normalize`, `/critique` (impeccable) | Design quality review, cleanup, consistency checks on frontend code |
| `/code-review <PR#>` | Reviewing a pull request; pass the PR number |
| `/ralph-loop "<task>"` | Autonomous iterative task with verifiable completion criteria |
| `/ralph-loop:help` | Unsure how to structure a ralph-loop prompt |
| `/prompt-review:review` | Before finalizing a complex prompt for an agent, tool, or production workflow |
| `/prompt-review:adapt [days]` | After 5+ reviews accumulated, to preview reviewer weight recalibration |
| `/prompt-review:adapt 30 --apply` | Apply weight recalibration after previewing |
| `/prompt-review:stats` | View prompt quality trends and reviewer effectiveness metrics |
| `/brainstorm` (superpowers) | Refine a vague idea through Socratic questioning before planning |
| `/write-plan` (superpowers) | Break implementation into bite-sized tasks with exact file paths |
| `/execute-plan` (superpowers) | Dispatch a written plan to parallel subagents |
| `/browse`, `/qa` (gstack) | Headless browser testing, QA verification, dogfooding user flows |
| `/ship` (gstack) | Pre-merge checklist: tests, lint, type-check, changelog |
| `/review` (gstack) | Code review with structured feedback |
| `/retro` (gstack) | Post-task retrospective |
| `/tiered-fanout` | Before dispatching 3+ parallel subagents/worktrees — dependency analysis + tier classification |
| `/ab-experiment` | Measuring whether a workflow/prompt/skill change actually helps — paired worktrees, blind grading |
| `/session-archaeology` | Any "check your claude logs" / retrospective / what-have-I-done question |
| `/honest-assessment` | After agent-heavy sprints or before reporting metrics — field-validated vs mock-derived audit |
| `/headless-claude-hygiene` | Before any batch/pipeline/test that shells out to `claude -p` |

**context7** is auto-invoked for library documentation lookups. Explicitly request it when working with unfamiliar APIs or when docs may be outdated.

**typescript-lsp** provides real TypeScript type checking via LSP — auto-invoked when working with TypeScript files.

## Git Commits

- **No Co-Authored-By trailers.** Do not add `Co-Authored-By` lines to commit messages. This includes any AI attribution trailers.

## Git Worktrees

Worktrees isolate feature work from the main checkout. Follow these rules consistently.

**Standard location:** All worktrees live under `.worktrees/` inside the repo root. This directory is gitignored by convention. Never create worktrees in arbitrary locations.

**Naming:** Name the worktree after the task, matching the branch name (e.g. `.worktrees/feat-login` for branch `feat/login`).

**One worktree per task.** Never let two unrelated tasks share a worktree or branch. Never let worktrees accumulate — remove them as soon as the branch is merged.

**Never check out `main` into a worktree for ongoing work.** Reference `origin/main` via `git fetch` instead.

**The primary checkout (repo root) stays on the active feature branch.** Do not switch the root checkout to main or another branch mid-session.

**`.claude/` in worktrees:** Each worktree gets its own `.claude/` directory checked out from git — do NOT symlink it back to the primary checkout. `.claude/` is fully tracked in private repos; skills, hooks, and plans committed on a feature branch are part of that branch and get reviewed in the PR like any other file. The old symlink convention caused `git diff` to break with "beyond a symbolic link" errors and required plumbing workarounds.

**Cleanup after merge — always do all three steps:**
```bash
git worktree remove .worktrees/<name>
git worktree prune
git branch -d <branch>
```

**For parallel agents:** Create all worktrees before spawning agents. Assign one worktree per agent and name them clearly.

**Audit command:**
```bash
git worktree list && git branch --merged main
```

## Claude Plans and Documentation

Keep all agent-facing docs, plans, and checklists in the project's `.claude/` directory (e.g. `~/git/myproject/.claude/`). For private repos `.claude/` is fully tracked in git — commit skills, hooks, plans, and specs alongside the code that uses them. Only `settings.local.json` and `run-logs/` stay untracked (machine-local auth and ephemeral session output).

When executing a plan from a `.claude/` document, re-read referenced source files fresh — do not rely on file content read earlier in the session. The plan is the source of truth; discard exploration-phase assumptions not captured in it.

## GitHub Operations

Use `git` directly for all git operations (push, pull, fetch, etc.). Do not use the `gh` CLI for git operations — it causes HTTP 400 / buffer errors on this machine. `gh` is fine for API-level tasks (creating repos, PRs, issues) but not for pushing/pulling.

**PR workflow:** Always push a feature branch then create a PR via `gh pr create` — never merge feature branches directly to main. PR body should include a summary, test plan, and any relevant notes.

## Local Dev Conventions

### Port Management (portless)

`portless` is installed globally (v0.4.1). When setting up or modifying dev scripts for a project:

- Wrap the dev command with `portless <project-name> <cmd>` in `package.json`
- Use the repo directory name as the portless name (e.g. `portless my-app next dev`)
- For multi-service projects, wrap each service separately (e.g. `portless my-app.api pnpm start`, `portless my-app.web next dev`)
- Do not hardcode port numbers in `.env` files or configs when portless is handling routing
- The proxy auto-starts on first use; can also be started explicitly with `portless proxy start`

## Things to Never Do

- Never use the system Node at `/usr/local/bin/node`
- Never commit `.env` files, API keys, or secrets
- Never push to main/master without asking
- Never install global npm packages without asking
- Never mutate state on repos Brian doesn't own — labels, PR metadata, bot commands, check reruns; comments and fork pushes only
- Never default a pipeline/tool to shelling out to `claude -p` — gate behind a flag, stub the binary in tests, scratch cwd + `--no-session-persistence` for batches (see /headless-claude-hygiene)
# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.
