# claude-personalities

Switchable Claude Code personalities using git branches and symlinks.

No npm packages. No external dependencies. One bash script and standard Unix tools.

## The problem

Claude Code's behavioral identity is spread across 15+ files under `~/.claude/` and `~/`. There's no built-in way to snapshot a configuration or switch between different agent setups. [Issue #7075](https://github.com/anthropics/claude-code/issues/7075) requests native support.

This repo is the workaround.

## How it works

```
git branch = personality profile
setup.sh = symlink manager
```

Each git branch holds a complete personality. `setup.sh` manages symlinks between the active branch's files and `~/.claude/`. Switching profiles is one command.

## Profiles

### `main` (base) — Daily driver

Full configuration: preferences, 8 plugins, gstack + exa-search skills, custom statusline, memory.

### `blank` — Clean slate

Machine environment facts only. No preferences, no plugins, no skills, no memory. Default permission mode.

## What's managed (personality) vs. what's not (runtime)

Only files that define agent behavior are tracked. Runtime state stays in `~/.claude/` untouched.

**Personality (managed per profile):**

| Item | Location | Notes |
|------|----------|-------|
| `CLAUDE.md` | `~/.claude/` | Primary personality definition |
| `settings.json` | `~/.claude/` | Permissions, plugins, hooks, statusline |
| `settings.local.json` | `~/.claude/` | Personal overrides |
| `MEMORY.md` | `~/.claude/` | Persistent memory |
| `keybindings.json` | `~/.claude/` | Custom keyboard shortcuts |
| `agents/` | `~/.claude/` | User-level subagents |
| `skills/` | `~/.claude/` | User-level skills |
| `rules/` | `~/.claude/` | Path-scoped rules |
| `commands/` | `~/.claude/` | Legacy slash commands |
| `mcp.json` | `~/.claude/` | User-level MCP config |
| `statusline-command.sh` | `~/.claude/` | Custom statusline script |
| `statusline-config.txt` | `~/.claude/` | Statusline display config |
| `run-project-hook.sh` | `~/.claude/` | Custom hook script |

**Runtime (untouched):** `projects/`, `history.jsonl`, `debug/`, `plans/`, `todos/`, `tasks/`, `teams/`, `sessions/`, `plugins/` (cache), and others.

Plugins are controlled via `enabledPlugins` in `settings.json`. The plugin cache stays on disk — switching profiles toggles which plugins are active, not which are installed.

## Setup

### Prerequisites

- Git
- An existing `~/.claude/` directory (i.e., you've used Claude Code at least once)

### First-time setup

```bash
# 1. Clone this repo (or fork it)
git clone <your-repo-url> ~/git/claude_personalities
cd ~/git/claude_personalities

# 2. Back up your current config
./setup.sh backup

# 3. Import your config into the repo
./setup.sh import

# 4. Commit as your base profile
git add -A && git commit -m "profile: base (imported from current config)"

# 5. Remove the real files from ~/.claude/ (they're backed up + in git)
# Remove each managed item that was imported:
rm ~/.claude/CLAUDE.md ~/.claude/settings.json  # etc.

# 6. Activate symlinks
./setup.sh use main
```

### Switching profiles

```bash
./setup.sh use blank     # switch to clean slate
./setup.sh use main      # switch back to daily driver
```

### Creating a new profile

```bash
# Branch from base
git checkout -b opinionated

# Edit personality files
vim claude/CLAUDE.md
vim claude/settings.json

# Commit and activate
git add -A && git commit -m "profile: opinionated"
./setup.sh use opinionated
```

## Commands

| Command | Description |
|---------|-------------|
| `./setup.sh use <branch>` | Switch profile (unlink, checkout, relink) |
| `./setup.sh current` | Print active profile |
| `./setup.sh list` | List available profiles |
| `./setup.sh status` | Show symlink health |
| `./setup.sh backup` | Back up current personality files |
| `./setup.sh import` | Import from `~/.claude/` into repo |
| `./setup.sh doctor` | Full health check |
| `./setup.sh drift` | Scan for unrecognized files |
| `./setup.sh changelog` | Fetch Claude Code changelog, filter for config changes |
| `./setup.sh pin-version` | Record Claude Code version for drift detection |

## Shell convenience (optional)

Add to `~/.zshrc`:

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

## Safety

- The switch command checks for uncommitted changes and aborts if the working tree is dirty
- Symlinks are only removed if they point back to this repo (`readlink` check)
- Real files are never overwritten — conflicts are warned, not resolved
- A backup is created before the first import

## Drift detection

Claude Code ships config changes regularly. This repo detects when new files appear:

- `./setup.sh drift` — scans `~/.claude/` for files not in MANAGED_ITEMS or KNOWN_RUNTIME
- `./setup.sh changelog` — fetches the Claude Code changelog and filters for config-relevant changes
- `./setup.sh pin-version` + `doctor` — tracks version changes between sessions

## How this works technically

The repo has two directories that mirror filesystem targets:

- `claude/` — contents symlink into `~/.claude/`
- `home/` — contents symlink into `~/`

Each git branch can have different files in these directories. `setup.sh use <branch>` does three things:

1. Removes all symlinks that point into this repo (safe — checks `readlink`)
2. Runs `git checkout <branch>`
3. Creates symlinks for all items that exist in the new branch

Items that exist in one profile but not another are handled correctly — they're linked when present and absent when not.

## Known limitations

- Switch profiles between sessions, not during. Settings load at session start.
- Plugin switching is enable/disable only. All plugins remain installed in the cache.
