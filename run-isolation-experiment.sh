#!/usr/bin/env bash
set -euo pipefail

# Isolation experiment: Which ingredient in opinionated causes the ex-bowling differentiation?
# 3 variant profiles × 1 task (ex-bowling) × 3 reps = 9 runs
# Plus blank as control = 12 total runs
# Estimated cost: $3-5 | Estimated time: ~10-15 minutes
#
# Run from a regular terminal (NOT inside Claude Code):
#   cd ~/git/claude_personalities && ./run-isolation-experiment.sh

TASK="ex-bowling"
REPS=3
VARIANTS=(tdd-only limits-only planning-only)
ORIGINAL_BRANCH=$(git branch --show-current)

# Stash any uncommitted changes so git checkout works
STASHED=false
if ! git diff --quiet 2>/dev/null; then
	echo "Stashing uncommitted changes..."
	git stash push -m "isolation-experiment-autostash" --quiet
	STASHED=true
fi

# Restore stash and branch on exit (even on failure)
cleanup() {
	git checkout "$ORIGINAL_BRANCH" 2>/dev/null || true
	if $STASHED; then
		echo "Restoring stashed changes..."
		git stash pop --quiet 2>/dev/null || true
	fi
}
trap cleanup EXIT

echo "╔══════════════════════════════════════════════════════╗"
echo "║  Isolation Experiment: ex-bowling only               ║"
echo "║  4 profiles × 3 reps = 12 runs                      ║"
echo "║  Profiles: blank, tdd-only, limits-only, planning    ║"
echo "║  Started: $(date '+%Y-%m-%d %H:%M:%S')                    ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Step 1: Create variant branches from blank (which has benchmarks/ already)
echo "Setting up variant branches..."

for variant in "${VARIANTS[@]}"; do
	branch="variant-${variant}"

	# Check if branch exists
	if git rev-parse --verify "$branch" >/dev/null 2>&1; then
		echo "  Branch '$branch' already exists, updating CLAUDE.md..."
		git checkout "$branch" 2>/dev/null
	else
		echo "  Creating branch '$branch' from blank..."
		git checkout blank 2>/dev/null
		git checkout -b "$branch" 2>/dev/null
	fi

	# Copy the variant CLAUDE.md
	cp "_experiment/claude-md-${variant}.md" "claude/CLAUDE.md"
	git add claude/CLAUDE.md
	git commit -m "Set up ${variant} variant profile" --allow-empty 2>/dev/null || true

	# Ensure benchmarks/ exists
	if [ ! -d "benchmarks/tasks" ]; then
		echo "  Syncing benchmarks/ from main..."
		git checkout main -- benchmarks/
		git add benchmarks/
		git commit -m "Sync benchmark tasks from main" 2>/dev/null || true
	fi
done

git checkout "$ORIGINAL_BRANCH" 2>/dev/null
echo ""

# Step 2: Run the experiment
PROFILES=(blank variant-tdd-only variant-limits-only variant-planning-only)
TOTAL=$(( ${#PROFILES[@]} * REPS ))
COUNT=0
FAILED=0
START_TIME=$(date +%s)

echo "Starting benchmark runs..."
echo ""

for rep in $(seq 1 $REPS); do
	for profile in "${PROFILES[@]}"; do
		COUNT=$((COUNT + 1))
		git checkout "$profile" 2>/dev/null

		ELAPSED=$(( $(date +%s) - START_TIME ))
		if [ "$COUNT" -gt 1 ]; then
			AVG_PER_RUN=$(( ELAPSED / (COUNT - 1) ))
			REMAINING=$(( (TOTAL - COUNT + 1) * AVG_PER_RUN ))
			ETA="~$(( REMAINING / 60 ))m remaining"
		else
			ETA="estimating..."
		fi

		printf "[%d/%d] rep=%d %-20s %s (%s)\n" "$COUNT" "$TOTAL" "$rep" "$profile" "$TASK" "$ETA"

		if ! ./setup.sh benchmark --task "$TASK" > /dev/null 2>&1; then
			echo "  ⚠ FAILED: $profile/$TASK (rep $rep)"
			FAILED=$((FAILED + 1))
		fi
	done
done

# cleanup trap handles branch restore and stash pop

ELAPSED=$(( $(date +%s) - START_TIME ))
MINUTES=$(( ELAPSED / 60 ))
SECONDS_REM=$(( ELAPSED % 60 ))

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Isolation experiment complete                       ║"
echo "║  $((COUNT - FAILED))/$TOTAL passed, $FAILED failed                           ║"
echo "║  Duration: ${MINUTES}m ${SECONDS_REM}s                                   ║"
echo "║  Finished: $(date '+%Y-%m-%d %H:%M:%S')                   ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Results in: _metrics/benchmarks/{blank,variant-tdd-only,variant-limits-only,variant-planning-only}/ex-bowling/"
echo ""
echo "Next: Come back to Claude Code to analyze results."
