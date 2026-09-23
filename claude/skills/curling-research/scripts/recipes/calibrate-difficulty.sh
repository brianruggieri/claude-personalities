#!/usr/bin/env bash
# calibrate-difficulty.sh — pull literature-grounded values for an AI tier.
#
# Usage:
#   calibrate-difficulty.sh <tier>     # tier ∈ easy|medium|hard|olympic
#
# Slugs queried: 12-ai-opponent-design, 06-player-roles, 05-strategy-analytics

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$SKILL_DIR/scripts/grounding-cache.sh"
COORDINATOR="$SKILL_DIR/scripts/coordinator"

# shellcheck source=/dev/null
source "$LIB"

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") <tier>" >&2
  echo "  tier ∈ easy | medium | hard | olympic" >&2
  exit 2
fi

tier="$1"
case "$tier" in
  easy|medium|hard|olympic) ;;
  *) echo "error: tier must be one of easy, medium, hard, olympic (got: $tier)" >&2; exit 2 ;;
esac

slugs="12-ai-opponent-design,06-player-roles,05-strategy-analytics"
recipe="calibrate-difficulty"
key="recipe:$recipe:$tier"

prompt="For a curling AI's \`$tier\` difficulty: what aim noise variance, weight noise variance, distribution type, and shot-selection bias does the literature suggest? Cite specific numerical values from instrumented-shot data and Olympic-level fitting where available."

echo "──────────────────────────────────────────────────────────────"
echo "recipe: $recipe"
echo "  tier : $tier"
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
