#!/usr/bin/env bash
# ui-screen.sh — research broadcast/lore conventions for a UI screen.
#
# Usage:
#   ui-screen.sh "<screen-name>" "<purpose>"
#
# Slugs queried: 09-broadcast, 10-culture-history, 11-game-design

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$SKILL_DIR/scripts/grounding-cache.sh"
COORDINATOR="$SKILL_DIR/scripts/coordinator"

# shellcheck source=/dev/null
source "$LIB"

if [[ $# -lt 2 ]]; then
  echo "usage: $(basename "$0") \"<screen-name>\" \"<purpose>\"" >&2
  exit 2
fi

screen="$1"
purpose="$2"

slugs="09-broadcast,10-culture-history,11-game-design"
recipe="ui-screen"
canonical=$(printf '%s|%s' "$screen" "$purpose" | tr 'A-Z' 'a-z' | tr -s ' ' '-')
key="recipe:$recipe:$canonical"

prompt="For a curling-game UI screen named \`$screen\` whose purpose is \`$purpose\`: (1) what broadcast/HUD conventions inform its layout, (2) what cultural/lore elements should the copy reflect, (3) what prior-art curling games have done well or poorly with this screen?"

echo "──────────────────────────────────────────────────────────────"
echo "recipe: $recipe"
echo "  screen : $screen"
echo "  purpose: $purpose"
echo "  slugs  : $slugs"

hit=$(cache_lookup "$key" || true)
if [[ -n "$hit" ]]; then
  ts=$(printf '%s' "$hit" | jq -r '.ts')
  fresh=$(printf '%s' "$hit" | jq -r '.fresh_until')
  summary=$(printf '%s' "$hit" | jq -r '.answer_summary')
  echo "  cache  : [cached] (asked $ts, fresh until $fresh)"
  echo "──────────────────────────────────────────────────────────────"
  echo "$summary"
  exit 0
fi

echo "  cache  : miss — querying coordinator"
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
