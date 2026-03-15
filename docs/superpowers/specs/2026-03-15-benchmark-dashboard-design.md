# Benchmark Dashboard — Design Spec

## Goal

Generate a self-contained HTML dashboard from `_metrics/benchmarks/` data, showing radar charts (6 axes per profile), cost comparison bars, trend lines, and a results table. Invoked via `./setup.sh benchmark --report --html`.

## Quality Scoring Protocol

verify.sh prints `SCORE:<0-100>` on its own line. The benchmark runner extracts it. If missing, defaults to 100 (pass) or 0 (fail).

Per-task scoring:
- hello-world: 100 if exact match, 0 otherwise
- fix-python-bug: (tests_passing / 5) * 100
- create-react-component: (criteria_met / 4) * 100
- write-unit-tests: min(100, test_count * 100 / 15), capped at 100
- review-code-diff: (issues_found / 4) * 100

## Enriched Result Format

Three fields added to each result JSON:

```json
{
  "quality_score": 75,
  "output_tokens_raw": 163,
  "cache_efficiency": 0.96
}
```

- `quality_score`: from SCORE line (0-100)
- `output_tokens_raw`: raw output token count (no normalization)
- `cache_efficiency`: cache_read / (cache_read + cache_creation + input_tokens), 0 if denominator is 0

## HTML Dashboard

Self-contained HTML with Chart.js via CDN. Written to `_metrics/dashboard.html`. Auto-opens in default browser.

### Layout (4 sections)

1. **Profile Radar Charts** — one radar per profile, 6 axes:
   - Pass rate (% tasks passed, 0-100)
   - Quality score (avg across tasks, 0-100)
   - Cost efficiency (inverse: lower cost = higher score, scaled 0-100 where cheapest profile = 100)
   - Speed (inverse: lower duration = higher score, scaled 0-100 where fastest = 100)
   - Token efficiency (inverse: fewer output tokens = higher score, scaled 0-100 where fewest = 100)
   - Cache efficiency (avg cache_efficiency * 100, 0-100)

2. **Cost Comparison** — grouped bar chart. X = tasks, grouped bars = profiles. Shows absolute cost.

3. **Trend Lines** — line charts for cost and quality score over time. X = run timestamps, one line per profile. Only rendered when 2+ runs exist for any profile.

4. **Results Table** — styled HTML table with pass/fail badges, cost, duration, quality score, output tokens. Color-coded by profile.

### Colors

One color per profile, consistent across all charts:
- blank: #3B82F6 (blue)
- main: #10B981 (green)
- opinionated: #F59E0B (amber)
- Additional profiles: #8B5CF6 (purple), #EF4444 (red), #EC4899 (pink)

### Radar Normalization

All 6 axes normalized to 0-100 for the radar chart:
- Pass rate: direct percentage
- Quality: direct (already 0-100)
- Cost efficiency: `(1 - cost/max_cost) * 100` where max_cost is the most expensive profile's average
- Speed: `(1 - duration/max_duration) * 100`
- Token efficiency: `(1 - tokens/max_tokens) * 100`
- Cache efficiency: direct percentage

This means higher = better on all axes. A perfect profile fills the entire radar.

## Command Integration

```bash
./setup.sh benchmark --report --html    # generate dashboard + open in browser
./setup.sh benchmark --report           # terminal output (unchanged)
```

The `--html` flag is only valid with `--report`. Running `benchmark --html` without `--report` is an error.

## Files Changed

| File | Action |
|------|--------|
| `benchmarks/tasks/*/verify.sh` | Modify: add SCORE output |
| `setup.sh` | Modify: extract SCORE from verify output, add fields to result JSON, add `_benchmark_html_report()`, update `cmd_benchmark` flag parsing |

## Constraints

- No external dependencies beyond Chart.js CDN
- Python3 stdlib only for HTML generation
- All data embedded as inline JSON in the HTML (no external data files)
- Dashboard works offline after initial Chart.js load (or degrades gracefully)
