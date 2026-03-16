# Multi-Run Experimental Protocol

## Purpose
Establish variance estimates for benchmark metrics to replace n=1 claims with
statistically grounded observations.

## Design
- **Tasks:** Same 5-task subset (he-000, mbpp-011, ex-bowling, ce-000, rf-001)
- **Profiles:** blank, main, opinionated
- **Repetitions:** 3 per cell (3 profiles x 5 tasks x 3 reps = 45 runs)
- **Estimated cost:** ~$10-15 (based on pilot: $3.50 for 15 single runs)
- **Estimated time:** ~1-2 hours

## Execution
Run from a regular terminal (not inside Claude Code):

```bash
for rep in 1 2 3; do
  for profile in blank main opinionated; do
    git checkout $profile
    for task in he-000-has-close-elements mbpp-011-remove-occ ex-bowling ce-000-regex-utils rf-001-command-output-hash; do
      ./setup.sh benchmark --task $task
    done
  done
done
git checkout main
```

Results land in `_metrics/benchmarks/<profile>/<task>/<timestamp>.json`.
Multiple runs produce multiple timestamped files per task per profile.

## Analysis
For each (profile, task) cell with 3 observations:
- Report median and IQR (not mean/stdev — too few observations for normality)
- For key metrics: cognitive_complexity_max, max_function_length, cost_usd
- Use Wilcoxon signed-rank test (paired by task) to compare profiles
- Report effect sizes (rank-biserial correlation)

## Success Criteria
- Claims using "consistently" require p < 0.05 on paired test
- Claims about "differences" require non-overlapping IQRs
- All findings qualified with sample size (n=3 per cell)
