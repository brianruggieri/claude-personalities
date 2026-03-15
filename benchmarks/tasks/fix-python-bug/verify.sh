#!/usr/bin/env bash
set -euo pipefail
dir="$1"

cd "$dir"
if python3 -m pytest test_calculator.py -v 2>&1; then
	echo "PASS"
	exit 0
else
	echo "FAIL: tests did not pass"
	exit 1
fi
