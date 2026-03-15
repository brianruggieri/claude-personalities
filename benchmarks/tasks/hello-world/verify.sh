#!/usr/bin/env bash
set -euo pipefail
dir="$1"

if [ ! -f "$dir/output.txt" ]; then
	echo "FAIL: output.txt not found"
	exit 1
fi

content="$(cat "$dir/output.txt")"
if [ "$content" = "Hello from Claude Code" ]; then
	echo "PASS"
	echo "SCORE:100"
	exit 0
else
	echo "FAIL: expected 'Hello from Claude Code', got '$content'"
	echo "SCORE:0"
	exit 1
fi
