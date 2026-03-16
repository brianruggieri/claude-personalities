#!/usr/bin/env bash
set -euo pipefail
dir="$1"
scorer="$(dirname "$0")/../../score-metrics.py"

cd "$dir"

# Check module file exists
if [ ! -f "paasio.py" ]; then
	echo "FAIL: paasio.py not found"
	echo "SCORE:0"
	exit 1
fi

# Run pytest
output="$(python3 -m pytest paasio_test.py -v 2>&1)" || true
echo "$output"

# Count PASSED and FAILED
passed="$(echo "$output" | grep -c "PASSED" || true)"
failed="$(echo "$output" | grep -c "FAILED" || true)"
total=$(( passed + failed ))

# Calculate score
if [ "$total" -gt 0 ]; then
	score=$(( passed * 100 / total ))
else
	score=0
fi

# Run shared metrics
python3 "$scorer" "$dir" '["paasio.py", "paasio_test.py"]' "python" 2>/dev/null || true

if [ "$passed" -eq "$total" ] && [ "$total" -gt 0 ]; then
	echo "PASS"
	echo "SCORE:$score"
	exit 0
else
	echo "FAIL: $passed/$total tests passed"
	echo "SCORE:$score"
	exit 1
fi
