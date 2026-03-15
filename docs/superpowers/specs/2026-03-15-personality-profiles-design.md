# Claude Code Personality Profiles — Design Spec

## Problem

Claude Code's behavioral identity is spread across 15+ files under `~/.claude/` and `~/`. There is no built-in mechanism to snapshot a known-good configuration or switch between different agent personalities. Issue [#7075](https://github.com/anthropics/claude-code/issues/7075) requests native support; it hasn't shipped.

## Solution

Git branches as profiles. A zero-dependency bash script manages symlinks between the active branch's files and `~/.claude/`. Each branch is a complete personality snapshot. This replaces the prior GNU Stow-based approach. The rewritten `setup.sh` has no external dependencies beyond bash, git, and standard Unix tools (`readlink`, `ln`, `cp`).

## Profiles

### `blank` — Clean slate

Machine environment facts only. No preferences, no plugins, no skills, no memory. The "factory reset" personality.

**Contents:**
```
claude/
├── CLAUDE.md           # Machine env only: nvm, rust, pyenv paths
└── settings.json       # {"permissions":{"defaultMode":"default"},"enabledPlugins":{}}
```

**Note:** `~/.claude.json` is runtime state managed by Claude Code, not a personality file. It is not tracked in this repo.

### `base` — Daily driver

Current production configuration. Full preferences, all plugins enabled, custom skills, statusline, memory.

**Contents:**
```
claude/
├── CLAUDE.md                 # Full 160-line config
├── settings.json             # All plugins, permissions, statusline, agent teams
├── settings.local.json       # Spinner tips disabled
├── MEMORY.md                 # Accumulated memory
├── statusline-command.sh     # Custom status line script
├── statusline-config.txt     # Status line display config
├── run-project-hook.sh       # Custom hook script
└── skills/
    ├── exa-search/           # Custom skill
    └── gstack/               # gstack suite (browse, qa, ship, review, retro, etc.)
        ├── browse
        ├── qa
        ├── ship
        ├── review
        ├── retro
        └── ... (full suite with symlinks)
```

## Managed Items

Two categories based on filesystem location:

### Inside `~/.claude/` (symlinked from `claude/` stow package)

| Item | Type | Notes |
|------|------|-------|
| `CLAUDE.md` | file | Primary personality definition |
| `settings.json` | file | Permissions, plugins, hooks, env vars, statusline |
| `settings.local.json` | file | Personal overrides |
| `MEMORY.md` | file | Persistent memory (auto-memory writes here) |
| `keybindings.json` | file | Custom keyboard shortcuts (when created) |
| `agents/` | dir | User-level subagent definitions |
| `skills/` | dir | User-level skills |
| `rules/` | dir | Path-scoped rules |
| `commands/` | dir | Legacy slash commands |
| `mcp.json` | file | User-level MCP config (inside ~/.claude/) |
| `statusline-command.sh` | file | Custom statusline script |
| `statusline-config.txt` | file | Statusline display settings |
| `run-project-hook.sh` | file | Custom hook script |

### NOT managed (runtime/ephemeral)

These stay in `~/.claude/` untouched regardless of active profile:

`projects/`, `history.jsonl`, `debug/`, `plans/`, `todos/`, `tasks/`, `teams/`, `sessions/`, `session-env/`, `shell-snapshots/`, `file-history/`, `paste-cache/`, `telemetry/`, `statsig/`, `.statsig/`, `cache/`, `backups/`, `downloads/`, `plugins/`, `stats-cache.json`, `debug.log`, `.DS_Store`, `.statusline-usage-cache`

The exact `KNOWN_RUNTIME` array in `setup.sh` must match this list so that `drift` detection works correctly.

Report artifacts in `~/.claude/` (BATCH*.md, API-REMOVAL-COMPLETE.md, etc.) are leftover files, not personality. They should be cleaned up manually before the initial import.

## Architecture

### Repository structure

```
claude_personalities/           # The git repo
├── README.md                   # Usage docs
├── setup.sh                    # All profile management logic
├── .gitignore                  # Excludes _backups/
├── .claude-code-version        # Pinned version for drift detection
├── claude/                     # Stow-style package (mirrors ~/.claude/)
│   ├── CLAUDE.md
│   ├── settings.json
│   ├── ... (varies per branch)
│   └── skills/
├── home/                       # Files targeting ~/ (currently empty)
├── _backups/                   # Timestamped backups (gitignored)
├── hooks/
│   └── drift-check-hook.sh    # Optional SessionStart hook
└── .github/
    └── workflows/
        └── watch-claude-code.yml  # Weekly changelog watcher
```

### Branching strategy

- `main` — the `base` (daily driver) profile
- `blank` — clean slate profile
- Future profiles branch from `main` or `blank` as appropriate
- Tags for stable snapshots: `v1-base`, `v1-blank`

### Symlink engine (~50 lines of bash)

Three core functions in `setup.sh`:

**`unlink_profile`** — Removes symlinks that point into this repo. Checks `readlink` target before removing. Never touches real files. Handles both `claude/` items (target: `~/.claude/`) and `home/` items (target: `~/`).

**`link_profile`** — Creates symlinks for items that exist in the current branch's `claude/` and `home/` directories. For `claude/` items, symlink target is `~/.claude/<item>`. For `home/` items, symlink target is `~/<item>`. Warns on conflicts (real file blocking a symlink). Skips items that don't exist in the profile.

**`cmd_use <branch>`** — Full switch. First checks for uncommitted changes (`git status --porcelain`) and aborts if the working tree is dirty — this prevents a broken state where symlinks have been removed but checkout fails. If clean: unlink old profile, `git checkout <branch>`, link new profile. On checkout failure, re-links the previous profile to avoid leaving the user with no symlinks.

### Known failure mode: symlink replacement by atomic writes

Some programs implement "safe writes" by deleting a file and recreating it (or writing to a temp file and renaming). If Claude Code does this with MEMORY.md or another managed file, the symlink would be destroyed and replaced with a regular file. The `status` and `doctor` commands detect this condition (a managed item that exists as a real file instead of a symlink) and warn the user.

### Conflict handling

If a real file (not a symlink) exists at a target path:
1. Warn the user
2. Do NOT overwrite
3. Suggest `./setup.sh backup` then manual removal

### Plugin management

Plugins are controlled exclusively via `enabledPlugins` in `settings.json`. The `plugins/` directory (cache, installed_plugins.json, marketplaces) is runtime — stays on disk untouched. Switching profiles toggles which plugins are active, not which are installed.

### Memory behavior

Each profile has its own `MEMORY.md`. When a profile is active, Claude Code's auto-memory writes go to that profile's MEMORY.md (via the symlink). Blank profile starts with no memory and stays clean unless explicitly written to. If auto-memory replaces the symlink with a real file (atomic write pattern), `doctor` will detect and warn.

## Commands

| Command | Description |
|---------|-------------|
| `./setup.sh backup` | Backup current ~/.claude/ personality files |
| `./setup.sh import` | Import personality files from ~/.claude/ into current branch |
| `./setup.sh use <branch>` | Switch profile: unlink, checkout, relink |
| `./setup.sh status` | Show symlink health for all managed items |
| `./setup.sh current` | Print active profile name (git branch) |
| `./setup.sh doctor` | Full health check: prereqs, symlinks, drift, version |
| `./setup.sh drift` | Scan ~/.claude/ for unrecognized files |
| `./setup.sh changelog` | Fetch Claude Code changelog, filter for config changes |
| `./setup.sh pin-version` | Record current Claude Code version |
| `./setup.sh list` | List available profiles (git branches) |

## Shell convenience function

Optional addition to `~/.zshrc`:

```bash
claude-profile() {
  local REPO="${CLAUDE_PROFILES_DIR:-$HOME/git/claude_personalities}"
  case "$1" in
    ls)      "$REPO/setup.sh" list ;;
    use)     "$REPO/setup.sh" use "$2" ;;
    current) "$REPO/setup.sh" current ;;
    diff)    git -C "$REPO" diff "$2" ${3:+$3} -- claude/ home/ ;;
    save)    git -C "$REPO" add -A && git -C "$REPO" commit -m "profile: $(git -C "$REPO" branch --show-current) — ${2:-auto-save}" ;;
    *)       echo "usage: claude-profile {ls|use|current|diff|save} [args]" ;;
  esac
}
```

## Drift detection (carried forward from prior work)

- `./setup.sh drift` — local scan for unrecognized files
- `./setup.sh changelog` — fetch + filter Claude Code changelog
- `./setup.sh pin-version` + `doctor` — version change detection
- Optional GitHub Action for weekly automated checks
- Optional SessionStart hook for per-session warnings

## Safety constraints

- Never switch profiles during an active Claude Code session
- Never overwrite real files — warn and require manual resolution
- Only remove symlinks that point back to this repo (`readlink` check)
- Backup before first import
- Runtime state files require care — backup before modifying

## Future-proofing

MANAGED_ITEMS includes items that don't currently exist (agents/, rules/, commands/, keybindings.json, mcp.json) so future profiles that use them get tracked automatically. The drift detection system surfaces new files Claude Code adds to `~/.claude/`.

When Claude Code ships native profile support (#7075), this tool becomes a migration path — export profiles to the native format and retire the symlink engine.

## Implementation plan

1. Initialize git repo, create `.gitignore`
2. Rewrite `setup.sh` with symlink engine + all commands (replaces all stow references)
3. Update `MANAGED_ITEMS` array to the 14-item list from this spec
4. Update `KNOWN_RUNTIME` array to match the full runtime list from this spec
5. Clean up legacy files from prior exploration (blog-post.md, old watch-claude-code.yml, old drift-check-hook.sh)
7. Clean up leftover report artifacts from `~/.claude/` (BATCH*.md, API-REMOVAL-COMPLETE.md, etc.)
8. Import current config as `base` profile on `main` branch using `./setup.sh import`
9. Commit as base profile
10. Create `blank` branch with minimal CLAUDE.md (machine env only) and default settings.json
11. Write README.md documenting the actual tool
12. Test: switch blank → base → blank, verify symlinks, verify drift detection, verify dirty-tree guard
