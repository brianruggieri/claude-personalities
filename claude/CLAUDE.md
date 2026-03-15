# User-Level CLAUDE.md — Brian Ruggieri

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

## Engineering Philosophy

- **No speculative features** — Don't add features, flags, or configuration unless actively needed right now.
- **No premature abstraction** — Don't create utilities until you've written the same code three times.
- **Clarity over cleverness** — Prefer explicit, readable code over dense one-liners.
- **Justify every dependency** — Each dependency is attack surface and maintenance burden. State purpose, alternatives, maintenance signals, and license before adding.
- **No phantom features** — Don't document, validate, or test features that aren't implemented.
- **Replace, don't deprecate** — When new replaces old, remove the old entirely. No backward-compatible shims, dual config formats, or migration paths. Flag dead code for removal.
- **Verify at every level** — Automated guardrails (linters, type checkers, tests) are the first step, not an afterthought. Zero warnings tolerance.
- **Bias toward action, gate on irreversibility** — Decide and move for anything easily reversed; state your assumption so reasoning is visible. Ask before committing to interfaces, data models, architecture, or destructive operations. If uncertain about intent, scope, or the right approach — ask before acting.
- **Finish the job, don't invent scope** — Handle edge cases you can see. Clean up what you touched. Flag (don't fix) broken adjacent code. Never expand scope without asking.

## Code Standards

### Hard Limits
- Functions: ≤50 lines. Suggest extraction beyond this.
- Cyclomatic complexity: ≤8. Refactor if exceeded.
- Positional parameters: ≤3. Use options objects or config patterns beyond this.
- Line width: 100 characters. Defer to project config if set.
- Absolute imports only — no relative (`..`) paths.

### Zero Warnings Policy
Fix every warning from every tool — linters, type checkers, compilers, tests. If a warning truly can't be fixed, add an inline ignore with a justification comment. Never leave warnings unaddressed.

### Cleanliness
- No commented-out code — delete it. That's what git is for.
- No magic numbers — extract to named constants with explanatory names.
- No TODOs without ticket numbers or issue references.
- Code should be self-documenting. If you need a comment to explain WHAT the code does, refactor the code instead. Comments explain WHY, never WHAT.

### Error Handling
- Fail fast with clear, actionable messages.
- Never swallow exceptions silently.
- Include context: what operation failed, what input caused it, suggested fix.
- No bare except/catch blocks.

## Testing Discipline

Every change that touches logic gets a test. No exceptions.

- **New behavior:** Write a failing test first. Then implement until it passes. Then refactor.
- **Bug fixes:** Write a failing regression test that reproduces the bug. Then fix. The test proves the fix works and prevents recurrence.
- **Test behavior, not implementation.** If a refactor breaks your tests but not your code, the tests were wrong.
- **Mock boundaries, not logic.** Only mock things that are slow, non-deterministic, or external (network, filesystem, clock).
- **Verify tests catch failures.** Break the code, confirm the test fails, then fix. If a test can't fail, it's not testing anything.
- **After any code change:** Run the project's test suite before considering the work done. On failure, fix before reporting done.

## Global Preferences

- **Indentation:** Tabs (defer to project config if it specifies otherwise)
- **Package manager:** npm
- **Commit style:** Brief imperative sentences ("Add login page", "Fix null check in parser")
- **Execution options:** When a skill offers execution choices (e.g. subagent-driven vs. parallel session), always pick the most cost-effective option without asking. Prefer subagent-driven development in the current session over spawning separate sessions.
- **Claude usage:** Use Claude subscription (Claude Code) for development work. Reserve API usage for when subscription-based tools are not practical (e.g., embedded in apps, custom integrations, production services).

### Communication Style

- **Terse by default.** Lead with the answer or action, not the reasoning. Skip filler, preamble, and transitions. If you can say it in one sentence, don't use three.
- **Explain only when non-obvious.** Reasoning is for surprising decisions, trade-offs, or when multiple approaches were considered. Don't explain routine work.
- **Structured output for multi-step work.** End with: Result (what happened), Scope (what was touched), Summary (one paragraph), Next steps (if any).
- **Banned words in PRs, commits, and comments:** critical, crucial, essential, significant, comprehensive, robust, elegant. Use plain, factual language.
- **Anti-rationalization.** Never claim work is done without evidence. "Tests pass" means you ran them and saw green. "Linter clean" means you ran it and saw zero warnings. Evidence before assertions, always.
- **Review = report, don't fix.** When asked to review code, list findings with severity. Don't silently fix things. Wait for direction on which to address.

## Workflow & Planning

- **1 file** = proceed directly.
- **2+ files** = create a TODO checklist before starting. Work through it sequentially.
- **3+ files** = write a plan to `.claude/` before implementing. The plan is the contract.
- **No mid-implementation redesign.** If the plan needs to change, update the plan first, then continue. Never drift silently.
- **Phase tracking.** Even for everyday tasks, mentally separate: understand (read code, ask questions, check git log) → plan (propose approach) → implement (write code per the agreed approach). If you catch yourself jumping ahead, say so and course-correct.
- **Git-log-first context.** Before diving into unfamiliar code, check `git log` for that path. Recent commit messages often explain the "why" faster than reading source.
- **Over-explore unfamiliar code.** When starting work in an area you haven't seen, read more files than you think you need. Assumptions from file names are wrong often enough to matter.

## Dependencies

Before adding ANY new dependency, state:
1. What it does and why it's needed
2. Alternatives considered (including stdlib/built-in)
3. Last commit date and open issue count
4. License (flag GPL-in-MIT contamination)

Wait for approval before `npm install` / equivalent.

- Prefer stdlib and built-in solutions over third-party packages.
- Security vulnerabilities in existing deps: fix immediately, don't defer.
- Run `npm audit` / equivalent before committing any dependency changes.
- Pin exact versions. No `^` or `~` in production dependencies.

## Orchestration Guide

Three mechanisms are available for multi-step and parallel work. Choose based on scope, duration, and verification needs.

| Mechanism | Use When | Avoid When |
|-----------|----------|------------|
| **Task agents** (`subagent_type` in Agent tool) | 3+ independent parallel subtasks within current session; research, exploration, or delegated implementation | Simple single-path tasks; when context sharing would require complex handoffs |
| **Agent Teams** (native, experimental) | Multi-agent coordination across separate sessions; parallel feature work with shared task list and messaging | Simple tasks completable in one focused session |
| **ralph-loop** (`/ralph-loop`) | Well-defined autonomous task that can run unattended; success is objectively verifiable (tests pass, linter clean, file exists); overnight generation tasks | Tasks requiring judgment calls mid-run; no clear pass/fail exit criteria |
| **Superpowers skills** (`/brainstorm`, `/write-plan`, `/execute-plan`) | Structured SDLC cycles: idea refinement → plan → parallel implementation → review; new feature work where quality matters | Quick ad-hoc changes; fixes where the path is already clear |

**Decision shortcut:**
- Need results in this session, tasks are parallel → Task agents
- Multi-session coordination with shared state → Agent Teams
- Well-defined task, can verify success automatically, can run overnight → ralph-loop
- Starting a significant new feature from scratch → Superpowers skills

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
| `learnings` (local) | Before debugging (search for prior solutions), after solving non-trivial issues (document the fix) |

**context7** is auto-invoked for library documentation lookups. Explicitly request it when working with unfamiliar APIs or when docs may be outdated.

**typescript-lsp** provides real TypeScript type checking via LSP — auto-invoked when working with TypeScript files.

## Knowledge Persistence

- **Before debugging:** Search `~/.claude/LEARNINGS.md` for relevant keywords. Apply confirmed solutions directly; try drafts with caution.
- **After solving a non-trivial issue:** Document it in LEARNINGS.md or promote an existing draft. Invoke the learnings skill for the full protocol.
- **Never skip this.** The 2 minutes spent searching saves the 30 minutes spent re-discovering.

## Security

- Flag any user input flowing to SQL, shell, eval, or template rendering without sanitization.
- No hardcoded secrets — no API keys, tokens, passwords, or connection strings in source. Ever.
- Audit dependencies before committing changes (see Dependencies section).
- When touching authentication, authorization, or data access: assume adversarial input. Validate at system boundaries.
- Prefer `trash` over `rm -rf`. Prefer reversible operations over destructive ones.

## Git Commits

- **No Co-Authored-By trailers.** Do not add `Co-Authored-By` lines to commit messages. This includes any AI attribution trailers.

## Git Worktrees

Worktrees isolate feature work from the main checkout. Follow these rules consistently.

**Standard location:** All worktrees live under `.worktrees/` inside the repo root. This directory is gitignored by convention. Never create worktrees in arbitrary locations.

**Naming:** Name the worktree after the task, matching the branch name (e.g. `.worktrees/feat-login` for branch `feat/login`).

**One worktree per task.** Never let two unrelated tasks share a worktree or branch. Never let worktrees accumulate — remove them as soon as the branch is merged.

**Never check out `main` into a worktree for ongoing work.** Reference `origin/main` via `git fetch` instead.

**The primary checkout (repo root) stays on the active feature branch.** Do not switch the root checkout to main or another branch mid-session.

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

## Pre-Commit Checklist

Before every commit:
1. Re-read your diff for unnecessary complexity, redundant code, and unclear naming.
2. Run relevant tests — confirm green.
3. Run linters and type checkers — fix everything. Zero warnings.
4. Check for hardcoded secrets, debug logging, and TODO comments without ticket references.
5. Confirm the commit message is imperative mood, describes the "why", and uses none of the banned words.

## PR Standards

- Describe what the code does now — not discarded approaches, prior iterations, or alternatives.
- Use plain, factual language. Banned words apply here too.
- Include a test plan: what was tested, how to verify, edge cases covered.
- One logical change per PR. If you're doing two unrelated things, it's two PRs.

## Claude Plans and Documentation

Keep all agent-facing docs, plans, and checklists in the project's `.claude/` directory (e.g. `~/git/myproject/.claude/`), not in the repo root. This keeps them out of git and out of the way of source files.

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
- Never use `rm -rf` — use `trash` or move to a temp directory
- Never use `sudo` in any command
- Never run `git push --force` or `git reset --hard` without explicit instruction
- Never pipe untrusted URLs to shell (`wget|bash`, `curl|sh`)
- Never modify `.env`, database migrations, or production configs autonomously — flag and ask
- Never expand scope beyond what was requested — flag adjacent issues, don't fix them
- Never claim work is complete without running tests and linters to confirm
