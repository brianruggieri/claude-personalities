#!/usr/bin/env bash
# rule-impact.sh — analyse a curling rule's text + strategic impact.
#
# Usage:
#   rule-impact.sh "<rule>"
#
# Slugs queried: 01-rules, 05-strategy-analytics, 11-game-design

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$SKILL_DIR/scripts/grounding-cache.sh"
COORDINATOR="$SKILL_DIR/scripts/coordinator"

# shellcheck source=/dev/null
source "$LIB"

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") \"<rule>\"" >&2
  exit 2
fi

rule="$1"

slugs="01-rules,05-strategy-analytics,11-game-design"
recipe="rule-impact"
canonical=$(printf '%s' "$rule" | tr 'A-Z' 'a-z' | tr -s ' ' '-' | sed 's/[^a-z0-9-]//g')
key="recipe:$recipe:$canonical"

prompt="Analyze the rule \`$rule\`: (1) the canonical text under World Curling 2024+, (2) the strategic impact on hammer/non-hammer play with citations to expected-points or steal-rate data, (3) which existing curling games modeled this rule well."

echo "──────────────────────────────────────────────────────────────"
echo "recipe: $recipe"
echo "  rule : $rule"
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
