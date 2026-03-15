#!/usr/bin/env bash
set -euo pipefail
dir="$1"

if [ ! -f "$dir/StatusBadge.jsx" ]; then
	echo "FAIL: StatusBadge.jsx not found"
	exit 1
fi

content="$(cat "$dir/StatusBadge.jsx")"
errors=""

# Check for default export
if ! echo "$content" | grep -qE "export default|module\.exports"; then
	errors="${errors}Missing default export. "
fi

# Check for status-badge class
if ! echo "$content" | grep -q "status-badge"; then
	errors="${errors}Missing status-badge CSS class. "
fi

# Check for data-testid
if ! echo "$content" | grep -q "data-testid"; then
	errors="${errors}Missing data-testid attribute. "
fi

# Check that it accepts status prop
if ! echo "$content" | grep -q "status"; then
	errors="${errors}Missing status prop usage. "
fi

if [ -z "$errors" ]; then
	echo "PASS"
	exit 0
else
	echo "FAIL: $errors"
	exit 1
fi
