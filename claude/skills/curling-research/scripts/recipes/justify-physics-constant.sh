#!/usr/bin/env bash
# justify-physics-constant.sh — defend a physics constant against literature.
#
# Usage:
#   justify-physics-constant.sh <name> <value> [unit]
#
# Slugs queried: 02-physics, 08-ice-technician

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$SKILL_DIR/scripts/grounding-cache.sh"
COORDINATOR="$SKILL_DIR/scripts/coordinator"

# shellcheck source=/dev/null
source "$LIB"

if [[ $# -lt 2 ]]; then
  echo "usage: $(basename "$0") <name> <value> [unit]" >&2
  exit 2
fi

name="$1"
value="$2"
unit="${3:-}"

slugs="02-physics,08-ice-technician"
recipe="justify-physics-constant"
key="recipe:$recipe:$name=$value${unit:+:$unit}"

if [[ -n "$unit" ]]; then
  prompt="Is \`$name = $value $unit\` defensible? What range does the literature support, what experimental data exists, and what's the failure mode if it's too high or too low?"
else
  prompt="Is \`$name = $value\` defensible? What range does the literature support, what experimental data exists, and what's the failure mode if it's too high or too low?"
fi

# Header.
echo "──────────────────────────────────────────────────────────────"
echo "recipe: $recipe"
echo "  args : $name = $value${unit:+ $unit}"
echo "  slugs: $slugs"

hit=$(cache_lookup "$key" || true)
if [[ -n "$hit" ]]; then
  ts=$(printf '%s' "$hit" | jq -r '.ts')
  fresh=$(printf '%s' "$hit" | jq -r '.fresh_until')
  summary=$(printf '%s' "$hit" | jq -r '.answer_summary')
  echo "  cache: [cached] (asked $ts, fresh until $fresh)"
  echo "──────────────────────────────────────────────────────────────"
  echo "$summary"
  exit 0
fi

echo "  cache: miss — querying coordinator"
echo "──────────────────────────────────────────────────────────────"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

if ! "$COORDINATOR" "$slugs" "$prompt" | tee "$tmp"; then
  echo "error: coordinator failed" >&2
  exit 1
fi

merged=$(jq -rs '
  map(.artifacts // [] | map(select(.name == "answer") | .parts // [] | map(.text // "") | join("\n")) | join("\n"))
  | join("\n\n--- next notebook ---\n\n")
' "$tmp" 2>/dev/null || true)

[[ -z "$merged" ]] && merged="(no answer text)"
cache_put "$key" "$slugs" "$prompt" "$merged" || true
