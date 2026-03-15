---
name: learnings
description: Cross-session knowledge base for non-trivial fixes and workarounds. Search before debugging, document after solving.
---

# Learnings Knowledge Base

Maintain `~/.claude/LEARNINGS.md` as a cross-session, cross-project knowledge base for non-trivial fixes, workarounds, and patterns.

## When to Invoke

- **Before debugging:** Stuck on a problem for more than 5 minutes — search LEARNINGS.md first.
- **After solving:** Just resolved a non-trivial issue — document it or promote an existing draft.
- **Starting a debugging session:** In unfamiliar territory — scan for relevant entries.

## File Location

`~/.claude/LEARNINGS.md` — shared across all profiles and projects. Never symlinked, never moved.

If the file doesn't exist, create it with:
```markdown
# LEARNINGS

Cross-session knowledge base. Managed by the learnings skill.
```

## Entry Format

```markdown
### [STATE] Short descriptive title `tag1` `tag2`
**Problem:** What went wrong or what was confusing
**Solution:** What fixed it, with exact commands or code if applicable
**Project:** Where it was encountered
**First seen:** YYYY-MM-DD
**File:** relative/path (if applicable)
```

Common tags: `platform`, `css`, `typescript`, `react`, `nextjs`, `performance`, `testing`, `sdk`, `architecture`, `tooling`, `git`, `config`

## State Machine

- `[DRAFT]` — First time a non-trivial fix is discovered. Default state for new entries.
- `[DRAFT]` → `[CONFIRMED]` — Same fix works a second time in a genuinely different context. Add `**Confirmed:** YYYY-MM-DD` line.
- `[DRAFT]` → `[INVALIDATED]` — Fix was wrong or no longer applies. Strikethrough the content, add `**Invalidated:** YYYY-MM-DD` and `**Reason:**` lines.
- `[CONFIRMED]` → `[REGRESSION]` — A confirmed fix stops working. Add `**Regression:** YYYY-MM-DD` and `**Context:**` lines. Create a new `[DRAFT]` entry with the updated fix.

## Search Protocol

1. Grep LEARNINGS.md for error messages, package names, file paths, or tags.
2. Apply `[CONFIRMED]` entries directly — these are trusted.
3. Try `[DRAFT]` entries with caution — they worked once but aren't proven.
4. Skip `[INVALIDATED]` entries unless the reason no longer applies.
5. If a `[REGRESSION]` entry exists, check whether its replacement draft has been confirmed.

## Promotion Rule

**Only promote on genuine re-encounter.** "Seems right" is not confirmation. The fix must actually work a second time in a different situation. Promote honestly.

## Maintenance

Periodically scan for stale entries:
- `[DRAFT]` entries older than 90 days with no confirmation — consider invalidating.
- `[REGRESSION]` entries with confirmed replacements — archive the regression.
