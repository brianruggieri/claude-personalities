# claude-personalities

Switchable Claude Code personality profiles via git branches + symlinks.

## Repo Structure

- `claude/` — mirrors `~/.claude/`. Contents are symlinked into `~/.claude/` when a profile is active.
- `home/` — mirrors `~/`. Contents (if any) are symlinked into `~/` when a profile is active. Currently empty — `home/.claude.json` was removed for security (PII/runtime state).
- `setup.sh` — all profile management commands (zero external dependencies).
- `docs/superpowers/specs/` — design spec for the profile system.
- `.claude/context-*.md` — context documents for specific workstreams.
- `_backups/` — timestamped backups (gitignored).

## Branches = Profiles

Each git branch is a personality profile. Switch with `./setup.sh use <branch>`.

| Branch | Purpose |
|--------|---------|
| `main` | Base daily driver — full config, 8 plugins, gstack skills |
| `blank` | Clean slate — machine env only, no plugins, no preferences |
| `opinionated` | Strict engineering opinions — TDD, code quality thresholds, 3 enforcement layers |

## Working Rules

- **Never run `./setup.sh use` during testing** in this session — it changes git branches and symlinks, which disrupts the active Claude Code session. Use it between sessions only.
- **Profile content** lives in `claude/` and `home/` only. Editing files elsewhere won't affect profiles.
- **setup.sh is infrastructure** — modify carefully. Changes affect all profiles.
- **Personality edits** go to `claude/CLAUDE.md`, `claude/settings.json`, `claude/skills/`, etc.
- **Context docs** in `.claude/` are for agent onboarding, not profile content.
- **Commit on the correct branch.** Check `git branch --show-current` before committing.

## Key Files

| File | What It Controls |
|------|-----------------|
| `claude/CLAUDE.md` | Agent behavioral instructions (the main personality definition) |
| `claude/settings.json` | Permissions, enabled plugins, hooks, env vars, statusline |
| `claude/settings.local.json` | Personal overrides |
| `claude/MEMORY.md` | Persistent memory per profile |
| `claude/skills/` | User-level skills (exa-search, gstack suite) |
| `claude/hooks/` | PreToolUse hook scripts (opinionated profile) |
| `setup.sh` | Profile management engine |

## Plugin Management

Plugins are toggled via `enabledPlugins` in `claude/settings.json`. Plugin cache in `~/.claude/plugins/` is never touched — switching profiles enables/disables, never installs/uninstalls.
