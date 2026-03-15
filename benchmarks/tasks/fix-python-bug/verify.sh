#!/usr/bin/env bash
set -euo pipefail
dir="$1"
scorer="$(dirname "$0")/../../score-metrics.py"

cd "$dir"
output="$(python3 -m pytest test_calculator.py -v 2>&1)" || true
echo "$output"

# Count passing tests out of 5
passed="$(echo "$output" | grep -c "PASSED" || true)"
total=5
score=$(( passed * 100 / total ))

# Run shared metrics (expected: only the two fixture files)
python3 "$scorer" "$dir" '["calculator.py", "test_calculator.py"]' "python" 2>/dev/null || true

if [ "$passed" -eq "$total" ]; then
	echo "PASS"
	echo "SCORE:$score"
	exit 0
else
	echo "FAIL: $passed/$total tests passed"
	echo "SCORE:$score"
	exit 1
fi
