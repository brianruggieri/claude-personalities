#!/usr/bin/env bash
set -euo pipefail
dir="$1"
scorer="$(dirname "$0")/../../score-metrics.py"

cd "$dir"

# Run AST-based refactoring verification
output="$(python3 verify_refactor.py 2>&1)" || true
echo "$output"

# Run shared metrics
python3 "$scorer" "$dir" '["diffsettings.py"]' "python" 2>/dev/null || true

if echo "$output" | grep -q "ALL_TESTS_PASSED"; then
	echo "PASS"
	echo "SCORE:100"
	exit 0
else
	echo "FAIL"
	echo "SCORE:0"
	exit 1
fi
