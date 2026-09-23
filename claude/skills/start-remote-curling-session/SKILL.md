---
name: start-remote-curling-session
description: >
  Kick off a `claude --remote-control` Claude Code session on the local
  Mac for the curling-game repo, optionally seeded with an opening
  prompt. Opens a fresh Ghostty window, runs the `curl-remote` shell
  alias (which cd's into ~/git/curling and starts the daemon under
  caffeinate), waits ~12s for startup, then sends the prompt as the
  first message. Use when: the user asks to "open a remote curling
  session", "start the desktop curling claude", "spin up curl-remote",
  or any equivalent. Useful as the bootstrap step for connecting a
  mobile/Android Claude session to the Mac's remote-control daemon.
---

# start-remote-curling-session

This skill wraps `~/.claude/scripts/start-remote-curling-session.sh` — a
bash + AppleScript helper that automates "open Ghostty → run
curl-remote → send a prompt." It exists so future Claude sessions
(on this Mac, OR remote sessions wanting to coordinate a bootstrap)
can reliably spin up the desktop daemon without the user repeating
the manual steps.

## Prerequisites (all already configured on this Mac)

- macOS with Ghostty.app installed
- `curl-remote` alias in `~/.zshrc`:
  `alias curl-remote='cd ~/git/curling && caffeinate -i claude --remote-control --dangerously-skip-permissions'`
- `claude` CLI on `$PATH` (at `~/.local/bin/claude`)
- Accessibility permission granted to whatever process invokes the
  script. The first run will silently no-op if permission isn't yet
  granted — visit System Settings → Privacy & Security → Accessibility
  and toggle the controlling process (typically Ghostty itself, since
  this skill is usually invoked from inside an existing Claude Code
  session running in Ghostty).

## How to invoke

Three equivalent forms:

```bash
# Default prompt is "hello"
~/.claude/scripts/start-remote-curling-session.sh

# Custom opening prompt
~/.claude/scripts/start-remote-curling-session.sh "review the current branch state"

# From a Claude Code session, just run the script via Bash tool
```

## What it does, step by step

1. **Sanity-checks** that `curl-remote` is defined in the interactive
   zsh and that `Ghostty.app` is installed. Exits non-zero with a
   diagnostic if either is missing.
2. **Snapshots** the current `claude --remote-control` PIDs (so the
   post-run probe can detect a new daemon vs. count an existing one).
3. **Drives Ghostty via AppleScript:**
   - `tell application "Ghostty" to activate` (launches if not running)
   - `Cmd-N` for a new window
   - Types `curl-remote` + Return
   - Waits 12 seconds for the daemon to attach
   - Types the prompt text + Return
4. **Probes** for new `claude --remote-control` PIDs and logs whether
   the bootstrap actually worked. If no new PID appears, the script
   prints diagnostic hints (Accessibility, alias stall, delay too
   short, claude crash).

## Tunables (edit the script directly)

- `delay 12` — startup window for claude. Bump on slow disks; lower on
  fast warm-starts.
- `delay 0.6 / 0.8` — Ghostty focus + window-open gaps. Usually fine.
- `${PROMPT_TEXT}` — comes from `$1`; defaults to `"hello"`.

## When to use

- **Bootstrapping from a different local session.** The current Claude
  Code session can spin up a separate desktop daemon without dropping
  the current context — useful for parallel agentic work.
- **Bootstrapping for mobile attach.** When the user wants to control
  the Mac from the Claude Code Android/iOS app, the daemon must be
  running first. This skill is the canonical local-bootstrap. (The
  mobile attach itself uses claude's remote-control channel, not this
  skill.)
- **Smoke-testing the remote-control pipeline.** Sending a known
  prompt and watching the new session respond verifies the daemon is
  healthy end-to-end.

## When NOT to use

- If a `claude --remote-control` daemon for `~/git/curling` is already
  running and you just want to send it another message. Use the
  mobile/remote attach instead — this skill specifically opens a NEW
  window with a NEW daemon (the duplication is intentional for
  bootstrapping, but wasteful for ongoing use).
- If you need synchronous "send and wait for response" semantics. The
  script fire-and-forgets — it sends the prompt and exits. The
  response lives in the new Ghostty window.
- On non-macOS systems. The whole thing is AppleScript-driven.

## Failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| Script exits with "alias not found" | `curl-remote` not in `.zshrc`, or `zsh -ilc` failed | Re-add the alias, confirm with `zsh -ilc 'type curl-remote'` |
| Script exits with "Ghostty.app not found" | Not installed | `brew install --cask ghostty` |
| Script reports "no NEW claude --remote-control process detected" | Accessibility blocked, OR delay too short, OR daemon crashed | Check System Settings → Privacy & Security → Accessibility for the invoking process; bump `delay 12` to `delay 18` if startup is slow; check the Ghostty window for crash output |
| "Input must be provided either through stdin..." printed during run | Cosmetic — keystroke landed during a brief window where claude's input handler was racing startup. Daemon still came up if the post-run probe found new PIDs. | Bump the `delay 12` window if you want the message gone |
| Multiple `claude --remote-control` processes accumulate over repeated runs | Each invocation spawns a new daemon by design | `pkill -f 'claude --remote-control'` between sessions if you want a clean slate |

## Companion artifacts

- **Script**: `~/.claude/scripts/start-remote-curling-session.sh`
- **Memory entry**: see `~/.claude/projects/-Users-brianruggieri-git-curling/memory/skill_start_remote_curling_session.md`
- **Underlying alias**: `~/.zshrc` → `curl-remote`
