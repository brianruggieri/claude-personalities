# Claude Memory

## Replying to PR Review Comments (GitHub API)

To reply to a PR review comment, use `in_reply_to` with the comment ID:

```bash
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments \
  -f body="Reply text here" \
  -F in_reply_to=COMMENT_ID
```

The `/replies` sub-endpoint does NOT exist. You must create a new comment on the pull with `in_reply_to` set to the parent comment ID.

When responding to automated reviewer comments (e.g. Copilot):
- If the suggestion is valid and fixed: reply with "Good catch — [what was done]. Fixed in [commit SHA]."
- If the suggestion is intentional/by-design: reply explaining the design rationale and say "No change here."
- If the suggestion doesn't apply to the project's context: reply with the reason (e.g. "localhost-only tool, HTTPS not applicable") and say "Leaving as-is."
- Keep replies concise — one or two sentences max.
