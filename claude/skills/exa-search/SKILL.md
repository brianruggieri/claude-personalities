---
name: exa-search
description: Deep semantic web search via Exa API when native WebSearch isn't sufficient. Use for research-quality queries, finding obscure technical content, or retrieving full page content for analysis.
---

# Exa Search Skill

Use this skill when native WebSearch returns poor results or when you need:
- Semantic/meaning-based search (not keyword matching)
- Full page content retrieval for LLM analysis
- Structured search with date filtering or domain targeting

## Prerequisites

The `EXA_API_KEY` environment variable must be set. If missing, tell the user to add it to `~/.zshrc`:
```bash
export EXA_API_KEY="your-key-here"
```

## Search

Standard semantic search. Returns URLs and optionally highlights/text.

```bash
curl -s https://api.exa.ai/search \
  -H "x-api-key: $EXA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "YOUR QUERY HERE",
    "numResults": 5,
    "type": "auto",
    "contents": {
      "highlights": { "numSentences": 3 }
    }
  }'
```

### Options

| Field | Values | Notes |
|-------|--------|-------|
| `type` | `"auto"`, `"keyword"`, `"neural"` | `auto` picks best mode |
| `numResults` | 1-10 | Keep low to save cost ($7/1k requests) |
| `contents.highlights` | `{ "numSentences": N }` | Compact summaries, cheapest |
| `contents.text` | `{ "maxCharacters": 4000 }` | Full text, use sparingly |
| `startPublishedDate` | `"2026-01-01T00:00:00.000Z"` | Filter to recent content |
| `includeDomains` | `["github.com", "arxiv.org"]` | Scope to trusted sources |
| `excludeDomains` | `["pinterest.com"]` | Filter out noise |

## Get Page Contents

Retrieve full content of known URLs (when you already have the URL).

```bash
curl -s https://api.exa.ai/contents \
  -H "x-api-key: $EXA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "ids": ["https://example.com/page"],
    "text": { "maxCharacters": 8000 }
  }'
```

## Cost Awareness

| Endpoint | Cost | When to use |
|----------|------|-------------|
| Search | $7/1k | Default — use highlights mode |
| Contents | $1/1k pages | When you need full page text |
| Answer | $5/1k | Skip — compose from search + contents |
| Research | $5-10/1k | Skip — too expensive for ad-hoc use |

Free tier: 1,000 requests/month. Prefer native WebSearch for simple lookups. Reserve Exa for when semantic depth matters.

## Response Handling

Parse the JSON response. Key fields:
- `results[].url` — the page URL
- `results[].title` — page title
- `results[].highlights` — extracted relevant sentences (if requested)
- `results[].text` — full page text (if requested)
- `results[].publishedDate` — when the page was published
