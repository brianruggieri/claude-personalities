#!/usr/bin/env bash
set -euo pipefail
dir="$1"

if [ ! -f "$dir/review.md" ]; then
	echo "FAIL: review.md not found"
	exit 1
fi

content="$(cat "$dir/review.md" | tr '[:upper:]' '[:lower:]')"
found=0

# Check for SQL injection detection
if echo "$content" | grep -qE "sql.?inject|f-string.*sql|string.?format.*query|unsanitized|parameterize"; then
	found=$((found + 1))
fi

# Check for hardcoded password/credential detection
if echo "$content" | grep -qE "hardcoded|hard.?coded|credential|db_password|admin123|secret.*code"; then
	found=$((found + 1))
fi

# Check for weak hashing detection
if echo "$content" | grep -qE "md5|weak.*hash|insecure.*hash|sha256.*removed|downgrade"; then
	found=$((found + 1))
fi

# Check for second SQL injection (admin_reset)
if echo "$content" | grep -qE "admin_reset|update.*inject|f.*update|second.*inject"; then
	found=$((found + 1))
fi

score=$(( found * 100 / 4 ))

if [ "$found" -ge 3 ]; then
	echo "PASS ($found/4 issues detected)"
	echo "SCORE:$score"
	exit 0
else
	echo "FAIL: only detected $found/4 expected issues"
	echo "SCORE:$score"
	exit 1
fi
