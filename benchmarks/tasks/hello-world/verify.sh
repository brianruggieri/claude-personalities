#!/usr/bin/env bash
set -euo pipefail
dir="$1"
scorer="$(dirname "$0")/../../score-metrics.py"

if [ ! -f "$dir/output.txt" ]; then
	echo "FAIL: output.txt not found"
	echo "SCORE:0"
	exit 1
fi

content="$(cat "$dir/output.txt")"

# Run shared metrics
python3 "$scorer" "$dir" '["output.txt"]' "text" 2>/dev/null || true

if [ "$content" = "Hello from Claude Code" ]; then
	echo "PASS"
	echo "SCORE:100"
	exit 0
else
	echo "FAIL: expected 'Hello from Claude Code', got '$content'"
	echo "SCORE:0"
	exit 1
fi
