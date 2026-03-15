#!/usr/bin/env bash
set -euo pipefail
dir="$1"
scorer="$(dirname "$0")/../../score-metrics.py"

if [ ! -f "$dir/test_validators.py" ]; then
	echo "FAIL: test_validators.py not found"
	echo "SCORE:0"
	exit 1
fi

cd "$dir"

# Tests must pass
test_output="$(python3 -m pytest test_validators.py -v 2>&1)" || true
echo "$test_output"

# Check if tests passed
if ! echo "$test_output" | grep -q "passed"; then
	echo "FAIL: tests did not pass"
	echo "SCORE:0"
	exit 1
fi

# Must test all three functions
content="$(cat test_validators.py)"
missing=""
for func in validate_email validate_password validate_username; do
	if ! echo "$content" | grep -q "$func"; then
		missing="${missing}$func "
	fi
done

if [ -n "$missing" ]; then
	echo "FAIL: missing tests for: $missing"
	echo "SCORE:10"
	exit 1
fi

# Count test functions
test_count="$(grep -c 'def test_' "$dir/test_validators.py")"
if [ "$test_count" -lt 8 ]; then
	echo "FAIL: only $test_count tests, expected at least 8"
	echo "SCORE:$(( test_count * 100 / 15 ))"
	exit 1
fi

# Score: scales up to 15 tests, capped at 100
score=$(( test_count * 100 / 15 ))
if [ "$score" -gt 100 ]; then
	score=100
fi

# Run shared metrics (expected: fixture + generated test file)
python3 "$scorer" "$dir" '["validators.py", "test_validators.py"]' "python" 2>/dev/null || true

echo "PASS ($test_count tests)"
echo "SCORE:$score"
exit 0
