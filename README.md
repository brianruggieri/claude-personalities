# dotfiles-claude

**Switchable Claude Code personalities using git branches + GNU Stow.**

No custom tooling. No npm packages. Just two tools that have been solving this problem since the 90s.

---

## The problem

Claude Code's behavioral identity is spread across 8+ files under `~/.claude/`. When you want to switch between configurations — say, a SuperClaude Framework setup for coding vs. a minimal writing-focused setup — there's no built-in mechanism to snapshot and swap.

[Issue #7075](https://github.com/anthropics/claude-code/issues/7075) on the Claude Code repo requests native profile support. It hasn't shipped. This repo is the workaround.

## The pattern

```
git branch = profile
stow = symlink manager
```

Each git branch holds a complete Claude Code personality. `stow` symlinks the active branch's files into `~/.claude/`. Switching profiles is `git checkout <branch> && stow -R claude -t ~/.claude`.

That's it. You get diffing, history, sharing, rollback, and multi-machine sync for free — because it's git.

## What's managed (personality) vs. what's not (runtime)

This repo only tracks files that define agent behavior. Runtime state stays in `~/.claude/` untouched.

**Tracked (personality):**

```
claude/
├── CLAUDE.md              # Global personality, preferences, memory directives
├── settings.json          # Permissions, model default, hooks, env vars
├── settings.local.json    # Personal overrides (⚠️ gitignore if public)
├── agents/                # User-level subagents
├── skills/                # User-level skills
├── rules/                 # User-level path-scoped rules
├── commands/              # Legacy slash commands
└── mcp.json               # User-level MCP server config
```

**Not tracked (runtime) — stays in ~/.claude/:**

```
projects/          # Session data, transcripts
history/           # Command history
todos/             # Todo state
statsig/           # Analytics/feature flags
credentials/       # Auth tokens
```

This distinction comes from reading the Claude Code source and docs. The `projects/` and `history/` directories are session artifacts. The `agents/`, `skills/`, `rules/`, and `settings.json` files are what make one Claude Code instance behave differently from another.

## Setup

### Prerequisites

- [GNU Stow](https://www.gnu.org/software/stow/) — `brew install stow` (macOS) or `sudo apt install stow` (Linux)
- Git
- An existing `~/.claude/` directory (i.e., you've used Claude Code at least once)

### First-time setup

```bash
# 1. Clone this repo
git clone https://github.com/YOUR_USERNAME/dotfiles-claude.git ~/dotfiles-claude
cd ~/dotfiles-claude

# 2. Back up your current ~/.claude/ personality files
./setup.sh backup
# → Creates timestamped backup in ~/dotfiles-claude/_backups/

# 3. Import your current config into the repo
./setup.sh import
# → Copies personality files from ~/.claude/ into claude/ directory

# 4. Commit as your first profile (the 'main' branch)
git add -A && git commit -m "profile: default (imported from current ~/.claude)"

# 5. Activate — symlink repo files into ~/.claude/
stow claude -t ~/.claude
```

### Creating a new profile

```bash
# Branch from current profile
git checkout -b superclaude

# Make changes — edit CLAUDE.md, add agents, swap settings
vim claude/CLAUDE.md
cp -r ~/SuperClaude_Framework/agents/* claude/agents/

# Commit
git add -A && git commit -m "profile: superclaude framework"

# Restow (repairs symlinks after branch switch)
stow -R claude -t ~/.claude
```

### Switching profiles

```bash
cd ~/dotfiles-claude
git checkout main        # or 'superclaude', 'writer', 'ops', etc.
stow -R claude -t ~/.claude
```

Or use the shell function below.

## Shell function (optional convenience)

Add to `~/.bashrc` or `~/.zshrc`:

```bash
claude-profile() {
  local DOTFILES="${CLAUDE_PROFILES_DIR:-$HOME/dotfiles-claude}"
  case "$1" in
    ls|list)
      git -C "$DOTFILES" branch --list | sed 's/^\*/→/' ;;
    use|switch)
      [ -z "$2" ] && echo "usage: claude-profile use <branch>" && return 1
      git -C "$DOTFILES" checkout "$2" && \
      stow -R -d "$DOTFILES" claude -t ~/.claude && \
      echo "Switched to profile: $2" ;;
    current)
      git -C "$DOTFILES" branch --show-current ;;
    diff)
      git -C "$DOTFILES" diff "$2" ${3:+$3} -- claude/ ;;
    save)
      git -C "$DOTFILES" add -A && \
      git -C "$DOTFILES" commit -m "profile: $(git -C "$DOTFILES" branch --show-current) — ${2:-auto-save}" ;;
    *)
      echo "usage: claude-profile {ls|use|current|diff|save} [args]" ;;
  esac
}
```

Then:
```bash
claude-profile ls                    # list profiles
claude-profile use superclaude       # switch
claude-profile current               # show active
claude-profile diff main superclaude # compare profiles
claude-profile save "added agents"   # commit current state
```

## tmux integration

If you use tmux (or ccp), show the active profile in your status bar:

```bash
# In .tmux.conf
set -g status-right '#(git -C ~/dotfiles-claude branch --show-current 2>/dev/null || echo "no-profile")'
```

## Stow ignore rules

The `.stow-local-ignore` file in this repo tells Stow to skip non-personality files:

```
# .stow-local-ignore
\.git
_backups
README\.md
setup\.sh
LICENSE
\.stow-local-ignore
```

## Branching strategy

The recommended approach:

- `main` — your default, daily-driver personality
- Feature branches for experimental or task-specific profiles
- Tag stable snapshots: `git tag v1-default`, `git tag v1-superclaude`

For sharing profiles with teammates, push branches to a shared remote. They clone and `stow`.

## Prior art and alternatives

This repo doesn't exist in a vacuum. Several people in the Claude Code ecosystem are already managing config with git:

- **[haberlah/dotfiles-claude](https://github.com/haberlah/dotfiles-claude)** — A forkable Claude Code config repo with auto-commit hooks that checkpoint every config change to git. Focused on a single configuration, not multiple switchable profiles, but the git-as-versioning approach is identical.

- **[evantahler/dot-claude](https://github.com/evantahler/dot-claude)** — Evan Tahler's global Claude Code config as a shareable dotfiles repo. Includes a `curl | sh` installer that merges with existing `~/.claude` data. Single-profile, single-branch.

- **[citypaul/.dotfiles](https://github.com/citypaul/.dotfiles)** — Full dotfiles repo using GNU Stow with Claude Code config as one package among many (git, bash, vim). Demonstrates the `stow claude` pattern in the wild.

- **[ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles)** — Nix Flakes + home-manager approach. Declarative Claude Code config with `agent-skills-nix` for skill deployment. The most infrastructure-heavy approach, but fully reproducible.

- **[kylelundstedt/dotfiles](https://github.com/kylelundstedt/dotfiles)** — Self-bootstrapping dotfiles with Claude Code agents, skills, and MCP setup via `install.sh`. Uses Stow for symlinking.

- **chezmoi** — A dedicated dotfiles manager written in Go. Handles templating, secrets encryption, and cross-machine differences in a single branch. More sophisticated than git+stow but requires learning chezmoi's conventions. One user has already integrated Claude Code config management with chezmoi.

The unique contribution of this repo is the **branches-as-profiles** pattern specifically for Claude Code config switching, rather than the more common single-branch dotfiles approach.

## What this is NOT

- **Not an npm package.** There's no `claude-profile` CLI to install. The shell function is optional sugar.
- **Not a framework.** It doesn't generate CLAUDE.md content for you or manage MCP servers.
- **Not a replacement for native profiles.** If/when Anthropic ships [#7075](https://github.com/anthropics/claude-code/issues/7075), use that. This is the bridge.

## Staying current with Claude Code changes

Claude Code ships 2-3 releases per week. Most are bug fixes, but roughly every 2-3 weeks there's a config-surface change — new settings, new directories, deprecations, or breaking changes. Recent examples:

- `autoMemoryDirectory` setting added (v2.1.74)
- `modelOverrides` setting added (v2.1.73)
- Plugin system with new `plugins/` directory (v2.0+)
- `CLAUDE.local.md` deprecated in favor of `@` imports
- `commands/` merged into `skills/` (commands still work, skills preferred)

This repo provides three layers of drift detection:

### 1. Local scan: `./setup.sh drift`

Scans `~/.claude/` for files that aren't in `MANAGED_ITEMS` (personality) or `KNOWN_RUNTIME` (ephemeral). If Claude Code adds a new directory or file, this surfaces it:

```
$ ./setup.sh drift
  ⚠ Found 1 unrecognized items in ~/.claude/:

    plugins/                      (directory, 12 files)

  These may be new Claude Code config files that should be added to MANAGED_ITEMS
  or KNOWN_RUNTIME in setup.sh. Check the changelog for context.
```

### 2. Changelog filter: `./setup.sh changelog`

Fetches Claude Code's CHANGELOG.md from GitHub, filters for config-relevant keywords (settings, CLAUDE.md, breaking, deprecated, agents, skills, hooks, etc.), and shows only what matters:

```
$ ./setup.sh changelog
Config-relevant changes (last 10 versions):

## 2.1.74
- Added autoMemoryDirectory setting to configure a custom directory for auto-memory storage
- Fixed managed policy ask rules being bypassed by user allow rules or skill allowed-tools
## 2.1.73
- Added modelOverrides setting to map model picker entries to custom provider model IDs
```

### 3. Version pinning: `./setup.sh pin-version`

Records your current Claude Code version. On the next `./setup.sh doctor` run, if the version has changed, you get a nudge to check the changelog:

```
$ ./setup.sh pin-version
Pinned version: 2.1.74

# Later, after Claude Code updates...
$ ./setup.sh doctor
  Claude Code updated: 2.1.74 → 2.1.76
  Run './setup.sh changelog' to check for config-related changes.
```

### 4. GitHub Action (optional): automated weekly check

The `.github/workflows/watch-claude-code.yml` workflow runs weekly, fetches the changelog, and opens a GitHub issue on your repo if it detects config-relevant changes since your pinned version. This way you get notified even if you forget to run `doctor` locally.

### 5. Claude Code hook (optional): session-start warning

Install `hooks/drift-check-hook.sh` as a `SessionStart` hook to get a one-line warning at the top of every Claude Code session if unrecognized files or a version change is detected:

```
[dotfiles-claude] ⚠ New files in ~/.claude/ not in your profile: plugins
[dotfiles-claude]   Run '~/dotfiles-claude/setup.sh drift' to investigate.
```

Add to your `settings.json`:
```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "bash ~/dotfiles-claude/hooks/drift-check-hook.sh"
      }
    ]
  }
}
```

### What this explicitly does NOT do

It does not auto-fix. When drift is detected, a human reviews the changelog, decides whether the new item is personality or runtime, and updates `MANAGED_ITEMS` or `KNOWN_RUNTIME` accordingly. This is intentional — the `commands/` → `skills/` migration, the `CLAUDE.local.md` deprecation, and the plugin system all required understanding context, not just adding a filename to a list.

## Files in this repo

```
dotfiles-claude/
├── README.md                              # This file
├── LICENSE                                # MIT
├── setup.sh                               # Backup, import, drift, changelog, doctor
├── .claude-code-version                   # Pinned version for drift detection
├── .stow-local-ignore                     # Tells stow what NOT to symlink
├── .gitignore                             # Excludes backups, local secrets
├── .github/
│   └── workflows/
│       └── watch-claude-code.yml          # Weekly changelog watcher → opens issues
├── hooks/
│   └── drift-check-hook.sh               # SessionStart hook for drift warnings
├── claude/                                # ← The stow package (mirrors ~/.claude/)
│   ├── CLAUDE.md
│   ├── settings.json
│   ├── agents/
│   │   └── .gitkeep
│   ├── skills/
│   │   └── .gitkeep
│   ├── rules/
│   │   └── .gitkeep
│   └── commands/
│       └── .gitkeep
└── _backups/                              # Auto-backups (gitignored)
```
