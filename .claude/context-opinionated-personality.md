# Context: Opinionated Personality Profile

## What This Repo Is

`claude-personalities` manages switchable Claude Code agent personalities via git branches + symlinks. A zero-dependency bash script (`setup.sh`) symlinks profile files from this repo into `~/.claude/` and `~/`.

Three profiles exist:
- `main` (base) — the user's daily driver. Full config with 8 plugins, gstack skills, statusline, memory.
- `blank` — clean slate. Machine env facts only, no plugins, no skills, no preferences.
- `opinionated` — **THIS IS WHAT YOU'RE BUILDING.** Branched from `main`. Currently identical to base.

## How Profiles Work

Each branch has a `claude/` directory (mirrors `~/.claude/`) and a `home/` directory (mirrors `~/`). The key personality files you'll be editing:

- `claude/CLAUDE.md` — The primary behavioral instructions. This is where most "opinions" go.
- `claude/settings.json` — Permissions, enabled plugins, hooks, env vars, statusline config.
- `claude/settings.local.json` — Personal overrides.
- `claude/skills/` — Custom skills (currently has exa-search + full gstack suite).

## The Base Profile You're Layering On

The base CLAUDE.md (`claude/CLAUDE.md` on `main`) contains:
- Machine environment (nvm, rust, pyenv paths)
- Global preferences (tabs, npm, commit style, communication style)
- Orchestration guide (task agents, agent teams, ralph-loop, superpowers)
- Skills reference table (when to invoke each skill)
- Git conventions (no co-authored-by, worktree rules)
- GitHub operations (use git directly, not gh for push/pull)
- Port management (portless)
- Things to never do

The base settings.json enables 8 plugins:
- superpowers, context7, code-review, ralph-loop (workflow)
- frontend-design, playwright, typescript-lsp (dev tools)
- impeccable (design quality from third-party marketplace)

Permission mode is `acceptEdits` with broad bash allow list.

## What "Opinionated" Means

The user wants a personality that goes beyond the neutral base by adding strong defaults and guardrails. Think of it as: base = "here's my environment and tools", opinionated = "here's how I want you to THINK and WORK."

Areas to explore with the user (use brainstorming skill):
- **Code quality opinions** — testing requirements, error handling philosophy, complexity limits
- **Workflow enforcement** — mandatory steps before committing, review requirements, planning thresholds
- **Communication style** — verbosity, when to explain vs. just do, how to handle ambiguity
- **Architecture opinions** — file organization, naming conventions, abstraction philosophy
- **Security posture** — stricter permission defaults, input validation requirements
- **Performance mindset** — bundle size awareness, query optimization, caching strategy
- **Hooks** — pre-commit checks, post-edit actions, session start routines

## Important Constraints

- The `opinionated` branch already exists and is checked out
- Don't modify `setup.sh` or repo infrastructure — only profile content files
- Keep `claude/CLAUDE.md` as the primary vehicle for opinions
- Plugin enablement changes go in `claude/settings.json` `enabledPlugins`
- Hook definitions go in `claude/settings.json` `hooks`
- New skills would go in `claude/skills/` but only if genuinely needed
- The user's machine environment section should stay unchanged (it's factual, not opinionated)
- Commit on the `opinionated` branch when done

## File Locations

- Repo: `~/git/claude_personalities/`
- Design spec: `docs/superpowers/specs/2026-03-15-personality-profiles-design.md`
- Current CLAUDE.md: `claude/CLAUDE.md`
- Current settings: `claude/settings.json`
- Setup script (read-only context): `setup.sh`
