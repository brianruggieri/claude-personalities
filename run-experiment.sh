#!/usr/bin/env bash
set -euo pipefail

# Follow-up experiment: 4 high-design-latitude tasks x 3 profiles x 3 reps = 36 runs
# Tests whether the ex-bowling differentiation result generalizes
# Estimated cost: $8-10 | Estimated time: ~30-45 minutes
#
# Run from a regular terminal (NOT inside Claude Code):
#   cd ~/git/claude_personalities && ./run-experiment.sh

TASKS=(
	ex-react
	ce-003-statistics3
	ex-linked-list
	ex-paasio
)
PROFILES=(blank main opinionated)
REPS=3

TOTAL=$(( ${#TASKS[@]} * ${#PROFILES[@]} * REPS ))
COUNT=0
FAILED=0
START_TIME=$(date +%s)

echo "╔══════════════════════════════════════════════════════╗"
echo "║  Benchmark Experiment: $TOTAL runs                       ║"
echo "║  ${#PROFILES[@]} profiles × ${#TASKS[@]} tasks × $REPS reps                       ║"
echo "║  Started: $(date '+%Y-%m-%d %H:%M:%S')                    ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Save current branch to restore later
ORIGINAL_BRANCH=$(git branch --show-current)

# Ensure benchmarks/ exists on all branches before starting
for profile in "${PROFILES[@]}"; do
	if [ "$profile" != "$ORIGINAL_BRANCH" ]; then
		echo "Checking benchmarks/ on branch '$profile'..."
		git checkout "$profile" 2>/dev/null
		if [ ! -d "benchmarks/tasks" ]; then
			echo "  Syncing benchmarks/ from main..."
			git checkout main -- benchmarks/
			git add benchmarks/
			git commit -m "Sync benchmark tasks from main (53 tasks)" || true
		fi
	fi
done
git checkout "$ORIGINAL_BRANCH" 2>/dev/null

echo ""
echo "Starting benchmark runs..."
echo ""

for rep in $(seq 1 $REPS); do
	for profile in "${PROFILES[@]}"; do
		git checkout "$profile" 2>/dev/null

		for task in "${TASKS[@]}"; do
			COUNT=$((COUNT + 1))
			ELAPSED=$(( $(date +%s) - START_TIME ))
			if [ "$COUNT" -gt 1 ]; then
				AVG_PER_RUN=$(( ELAPSED / (COUNT - 1) ))
				REMAINING=$(( (TOTAL - COUNT + 1) * AVG_PER_RUN ))
				ETA="~$(( REMAINING / 60 ))m remaining"
			else
				ETA="estimating..."
			fi

			printf "[%d/%d] rep=%d %-13s %-30s (%s)\n" "$COUNT" "$TOTAL" "$rep" "$profile" "$task" "$ETA"

			if ! ./setup.sh benchmark --task "$task" > /dev/null 2>&1; then
				echo "  ⚠ FAILED: $profile/$task (rep $rep)"
				FAILED=$((FAILED + 1))
			fi
		done
	done
done

# Return to original branch
git checkout "$ORIGINAL_BRANCH" 2>/dev/null

ELAPSED=$(( $(date +%s) - START_TIME ))
MINUTES=$(( ELAPSED / 60 ))
SECONDS=$(( ELAPSED % 60 ))

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Experiment complete                                ║"
echo "║  $((COUNT - FAILED))/$TOTAL passed, $FAILED failed                           ║"
echo "║  Duration: ${MINUTES}m ${SECONDS}s                                   ║"
echo "║  Finished: $(date '+%Y-%m-%d %H:%M:%S')                   ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. python3 benchmarks/aggregate-results.py _metrics/"
echo "  2. Open a new Claude Code session to update the dashboard"
echo "     with the handoff doc: .claude/handoff-multi-run-experiment.md"
