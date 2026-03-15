#!/usr/bin/env bash
set -euo pipefail
dir="$1"

if [ ! -f "$dir/test_validators.py" ]; then
	echo "FAIL: test_validators.py not found"
	exit 1
fi

cd "$dir"

# Tests must pass
if ! python3 -m pytest test_validators.py -v 2>&1; then
	echo "FAIL: tests did not pass"
	exit 1
fi

# Must test all three functions (at least one test per function)
content="$(cat test_validators.py)"
missing=""
for func in validate_email validate_password validate_username; do
	if ! echo "$content" | grep -q "$func"; then
		missing="${missing}$func "
	fi
done

if [ -n "$missing" ]; then
	echo "FAIL: missing tests for: $missing"
	exit 1
fi

# Must have at least 8 test functions (reasonable minimum for 3 validators)
test_count="$(grep -c 'def test_' "$dir/test_validators.py")"
if [ "$test_count" -lt 8 ]; then
	echo "FAIL: only $test_count tests, expected at least 8"
	exit 1
fi

echo "PASS ($test_count tests)"
exit 0
