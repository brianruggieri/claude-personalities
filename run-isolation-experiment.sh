#!/usr/bin/env bash
set -euo pipefail

# Isolation experiment: Which ingredient in opinionated causes the ex-bowling differentiation?
# 3 variant profiles × 1 task (ex-bowling) × 3 reps = 9 runs
# Plus blank as control = 12 total runs
# Estimated cost: $3-5 | Estimated time: ~10-15 minutes
#
# Run from a regular terminal (NOT inside Claude Code):
#   cd ~/git/claude_personalities && ./run-isolation-experiment.sh

TASKS=(
	he-000-has-close-elements
	mbpp-011-remove-occ
	ex-bowling
	ce-000-regex-utils
	rf-001-command-output-hash
	ex-react
	ce-003-statistics3
	ex-linked-list
	ex-paasio
)
REPS=3
VARIANTS=(limits-amplified)
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
echo "║  Limits-Amplified Experiment: 9 tasks                ║"
echo "║  1 profile × 9 tasks × 3 reps = 27 runs             ║"
echo "║  Profile: limits-amplified (max 20 lines, cc ≤ 5)   ║"
echo "║  Started: $(date '+%Y-%m-%d %H:%M:%S')                    ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Step 1: Create variant branches from blank
# Copy variant CLAUDE.md files to a temp dir first (they only exist on main)
echo "Setting up variant branches..."
TMPDIR=$(mktemp -d)
for variant in "${VARIANTS[@]}"; do
	cp "_experiment/claude-md-${variant}.md" "$TMPDIR/"
done

for variant in "${VARIANTS[@]}"; do
	branch="variant-${variant}"

	if git rev-parse --verify "$branch" >/dev/null 2>&1; then
		echo "  Branch '$branch' already exists, updating CLAUDE.md..."
		git checkout "$branch" 2>/dev/null
	else
		echo "  Creating branch '$branch' from blank..."
		git checkout blank 2>/dev/null
		git checkout -b "$branch" 2>/dev/null
	fi

	# Copy from temp dir (survives branch switch)
	cp "$TMPDIR/claude-md-${variant}.md" "claude/CLAUDE.md"
	git add claude/CLAUDE.md
	git commit -m "Set up ${variant} variant profile" --allow-empty 2>/dev/null || true

	if [ ! -d "benchmarks/tasks" ]; then
		echo "  Syncing benchmarks/ from main..."
		git checkout main -- benchmarks/
		git add benchmarks/
		git commit -m "Sync benchmark tasks from main" 2>/dev/null || true
	fi
done

rm -rf "$TMPDIR"
git checkout "$ORIGINAL_BRANCH" 2>/dev/null
echo ""

# Step 2: Run the experiment
PROFILES=()
for variant in "${VARIANTS[@]}"; do
	PROFILES+=("variant-${variant}")
done
TOTAL=$(( ${#PROFILES[@]} * ${#TASKS[@]} * REPS ))
COUNT=0
FAILED=0
START_TIME=$(date +%s)

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

			printf "[%d/%d] rep=%d %-20s %-30s (%s)\n" "$COUNT" "$TOTAL" "$rep" "$profile" "$task" "$ETA"

			if ! ./setup.sh benchmark --task "$task" > /dev/null 2>&1; then
				echo "  ⚠ FAILED: $profile/$task (rep $rep)"
				FAILED=$((FAILED + 1))
			fi
		done
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
echo "Results in: _metrics/benchmarks/variant-limits-amplified/*/"
echo ""
echo "Next: Come back to Claude Code to analyze results."
