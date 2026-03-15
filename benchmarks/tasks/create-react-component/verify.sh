#!/usr/bin/env bash
set -euo pipefail
dir="$1"

if [ ! -f "$dir/StatusBadge.jsx" ]; then
	echo "FAIL: StatusBadge.jsx not found"
	echo "SCORE:0"
	exit 1
fi

content="$(cat "$dir/StatusBadge.jsx")"
criteria=0
total=4

# Check for default export
if echo "$content" | grep -qE "export default|module\.exports"; then
	criteria=$((criteria + 1))
fi

# Check for status-badge class
if echo "$content" | grep -q "status-badge"; then
	criteria=$((criteria + 1))
fi

# Check for data-testid
if echo "$content" | grep -q "data-testid"; then
	criteria=$((criteria + 1))
fi

# Check that it accepts status prop
if echo "$content" | grep -q "status"; then
	criteria=$((criteria + 1))
fi

score=$(( criteria * 100 / total ))

if [ "$criteria" -eq "$total" ]; then
	echo "PASS"
	echo "SCORE:$score"
	exit 0
else
	echo "FAIL: $criteria/$total criteria met"
	echo "SCORE:$score"
	exit 1
fi
