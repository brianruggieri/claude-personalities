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
	exit 0
else
	echo "FAIL: expected 'Hello from Claude Code', got '$content'"
	exit 1
fi
