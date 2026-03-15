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
