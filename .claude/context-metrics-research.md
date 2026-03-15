# Context: Metrics & Visualization Research

## Implemented Metrics (as of this session)

### Tier 1 (bash-native)
- Extra file detection, line count, instruction adherence (CONSTRAINTS)

### Tier 2 (python3 stdlib)
- Lint issues (AST-based), cyclomatic complexity, function length

### Tier 3 (analyzers)
- Security smells (9 regex patterns)
- Naming quality (AST + blocklist + convention check)
- Over-engineering detection (vs expected_complexity in task.json)
- Regression detection (PASS_TO_PASS for fix-python-bug)
- LLM-as-judge (5-dimension rubric via claude -p subscription)

### In Progress
- Cognitive complexity (nesting-aware, better than cyclomatic)
- Halstead volume + maintainability index
- Duplicate block detection (AST subtree comparison)
- Personality compliance (checks CLAUDE.md rules against output)

## Future Metrics (from research, not yet implemented)

| Metric | Value | Effort |
|--------|-------|--------|
| PASS_TO_PASS (all tasks) | Catches 7.8% of false-positive patches | Low |
| Cost-per-correct | cost / pass_rate per profile | Trivial |
| Iterations to pass | First-try vs retry success | Medium |
| Runtime efficiency | O(n) vs O(n^2) detection | Medium |
| Edit distance from reference | Closeness to known-good solution | Low |
| Instruction violations | Systematic constraint checking | Medium |

## Dashboard Visualizations

### Implemented
- 10-axis radar chart (min-max scaled 30-95)
- Output tokens per task (grouped bars)
- Token breakdown by profile (stacked bars)
- Trend lines (when 2+ runs exist)
- Detailed results table

### In Progress
- Gauge KPI cards (composite fitness per profile)
- Heatmap grid (profile x metric colored matrix)
- Pareto scatter (tokens vs quality)

### Future (from research, not yet implemented)
- Box plots for variance across runs (chartjs-chart-boxplot plugin)
- Parallel coordinates plot (all dimensions at once)
- Error bars on bar charts (lightweight variance)
- Slope chart (before/after comparison)
- Background zones (green/yellow/red performance bands)
- Personality signature radar (differential fill vs baseline)
- Sparkline grid in results table

## Key Insight

**PERSONALITY_COMPLIANCE is the highest-value metric** for this specific use case.
It directly answers "is the personality profile doing what it claims?" — which is
the entire point of comparing profiles. Extract rules from CLAUDE.md, check output.

## Chart.js Plugin Stack (CDN, zero npm)

| Plugin | CDN | Purpose |
|--------|-----|---------|
| chartjs-chart-boxplot | jsdelivr | Box plots for variance (future) |
| chartjs-chart-matrix | jsdelivr | Heatmap grids (future, currently using HTML table) |
| chartjs-plugin-annotation | chartjs.org | Threshold lines, Pareto frontier (future) |
| chartjs-plugin-datalabels | netlify | Value labels on charts (future) |

## Sources

- SWE-bench: 29.6% of patches differ from ground truth
- GitClear: code churn rate rose from 3.1% to 5.7% with AI
- Qodo 2025: AI PRs are 154% larger than human
- ENAMEL: GPT-4 pass@1=0.831 but efficiency@1=0.454
- LiveCodeBench: self-repair iteration count matters
