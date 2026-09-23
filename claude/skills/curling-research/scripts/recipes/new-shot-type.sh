#!/usr/bin/env bash
# new-shot-type.sh — research a curling shot type before implementing it.
#
# Usage:
#   new-shot-type.sh "<shot name>" [optional context]
#
# Slugs queried: 04-shot-taxonomy, 02-physics, 12-ai-opponent-design

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$SKILL_DIR/scripts/grounding-cache.sh"
COORDINATOR="$SKILL_DIR/scripts/coordinator"

# shellcheck source=/dev/null
source "$LIB"

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") \"<shot name>\" [context]" >&2
  exit 2
fi

shot="$1"
shift || true
context="$*"

slugs="04-shot-taxonomy,02-physics,12-ai-opponent-design"
recipe="new-shot-type"
# Cache key uses the shot name + optional context, lowercased + dash-collapsed.
canonical=$(printf '%s %s' "$shot" "$context" | tr 'A-Z' 'a-z' | tr -s ' ' '-' | sed 's/-$//')
key="recipe:$recipe:$canonical"

prompt="For implementing a \`$shot\` shot in our curling game"
if [[ -n "$context" ]]; then
  prompt="$prompt (context: $context)"
fi
prompt="$prompt: (1) what's the canonical definition and weight/handle requirements per coaching literature, (2) what physics behavior should the simulation model, (3) how should the AI evaluate this shot's success/failure?"

echo "──────────────────────────────────────────────────────────────"
echo "recipe: $recipe"
echo "  shot : $shot${context:+ ($context)}"
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
