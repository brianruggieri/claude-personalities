#!/usr/bin/env bash
set -euo pipefail
dir="$1"
scorer="$(dirname "$0")/../../score-metrics.py"

cd "$dir"
output="$(python3 test_solution.py 2>&1)" || true
echo "$output"

# Run shared metrics
python3 "$scorer" "$dir" '["solution.py", "test_solution.py"]' "python" 2>/dev/null || true

if echo "$output" | grep -q "ALL_TESTS_PASSED"; then
	echo "PASS"
	echo "SCORE:100"
	exit 0
else
	echo "FAIL"
	echo "SCORE:0"
	exit 1
fi
