#!/usr/bin/env bash
# grounding-cache.sh — sourced library for the research-grounding cache.
#
# NOT a standalone script. Source it from another script:
#   source "$SKILL_DIR/scripts/grounding-cache.sh"
#
# Cache file: ~/.cache/curling-research/grounding-cache.jsonl
# Pending log: ~/.cache/curling-research/grounding-pending.jsonl
# History log: ~/.cache/curling-research/grounding-history.jsonl
#
# Each cache entry is a single JSON line:
#   {"key":"<cache-key>","ts":"<iso-utc>","slugs":"02-physics,12-ai-opponent-design",
#    "query_hash":"<sha1>","answer_summary":"<first-200-chars>","fresh_until":"<iso-utc>"}
#
# Functions:
#   cache_lookup <key>           → echo entry JSON if fresh, empty otherwise
#   cache_put <key> <slugs> <q> <a>  → append fresh entry, roll older same-key
#   cache_purge_stale            → drop entries with fresh_until < now
#   cache_pending_path           → echo path to the pending log
#   cache_history_path           → echo path to the history log
#   cache_path                   → echo path to the cache itself
#
# TTL: configurable via CURLING_RESEARCH_CACHE_TTL_DAYS (default 7).

CURLING_RESEARCH_CACHE_DIR="${CURLING_RESEARCH_CACHE_DIR:-$HOME/.cache/curling-research}"
CURLING_RESEARCH_CACHE_FILE="$CURLING_RESEARCH_CACHE_DIR/grounding-cache.jsonl"
CURLING_RESEARCH_PENDING_FILE="$CURLING_RESEARCH_CACHE_DIR/grounding-pending.jsonl"
CURLING_RESEARCH_HISTORY_FILE="$CURLING_RESEARCH_CACHE_DIR/grounding-history.jsonl"
CURLING_RESEARCH_CACHE_TTL_DAYS="${CURLING_RESEARCH_CACHE_TTL_DAYS:-7}"

cache_path()         { printf '%s\n' "$CURLING_RESEARCH_CACHE_FILE"; }
cache_pending_path() { printf '%s\n' "$CURLING_RESEARCH_PENDING_FILE"; }
cache_history_path() { printf '%s\n' "$CURLING_RESEARCH_HISTORY_FILE"; }

_cache_ensure_dir() {
  mkdir -p "$CURLING_RESEARCH_CACHE_DIR" 2>/dev/null || return 1
}

# Echo current UTC time as epoch seconds (portable: macOS bash 3.2 + GNU).
_cache_now_epoch() { date -u +%s; }

# Echo current UTC time as ISO8601 string.
_cache_now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Convert ISO8601 → epoch seconds. macOS BSD `date -j` syntax preferred,
# GNU `date -d` fallback. Returns 0 on failure (treated as "stale").
_cache_iso_to_epoch() {
  local iso="$1"
  local epoch
  if epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null); then
    printf '%s' "$epoch"
  elif epoch=$(date -u -d "$iso" +%s 2>/dev/null); then
    printf '%s' "$epoch"
  else
    printf '0'
  fi
}

# Echo an iso timestamp N days from now.
_cache_iso_plus_days() {
  local days="$1"
  local now_epoch
  now_epoch=$(_cache_now_epoch)
  local target=$((now_epoch + days * 86400))
  if date -u -r "$target" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; then
    return 0
  elif date -u -d "@$target" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; then
    return 0
  fi
  # Last-ditch fallback: just emit "now" if both BSD/GNU forms fail.
  _cache_now_iso
}

# SHA-1 of stdin → hex string. Prefer sha1sum (Linux), fall back to shasum
# (macOS default), then openssl. Echoes empty string on total failure.
_cache_sha1() {
  if command -v sha1sum >/dev/null 2>&1; then
    sha1sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 1 | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl sha1 | awk '{print $NF}'
  else
    printf ''
  fi
}

# cache_lookup <key> → echo entry JSON if fresh, empty otherwise.
cache_lookup() {
  local key="$1"
  [[ -z "$key" ]] && return 1
  [[ -f "$CURLING_RESEARCH_CACHE_FILE" ]] || return 0
  local now_epoch
  now_epoch=$(_cache_now_epoch)
  # Most recent (last) entry wins for a given key.
  local entry
  entry=$(jq -c --arg k "$key" 'select(.key == $k)' "$CURLING_RESEARCH_CACHE_FILE" 2>/dev/null | tail -n1)
  [[ -z "$entry" ]] && return 0
  local fresh_until
  fresh_until=$(printf '%s' "$entry" | jq -r '.fresh_until // ""')
  [[ -z "$fresh_until" ]] && return 0
  local fresh_epoch
  fresh_epoch=$(_cache_iso_to_epoch "$fresh_until")
  if [[ "$fresh_epoch" -gt "$now_epoch" ]]; then
    printf '%s\n' "$entry"
  fi
  return 0
}

# cache_put <key> <slugs> <query> <answer>
# Appends a fresh entry. We do NOT rewrite the file to remove older entries
# with the same key — `cache_lookup` always returns the most recent match.
# `cache_purge_stale` does the file rewrite during compaction.
cache_put() {
  local key="$1" slugs="$2" query="$3" answer="$4"
  [[ -z "$key" ]] && return 1
  _cache_ensure_dir || return 1
  local ts fresh_until query_hash summary
  ts=$(_cache_now_iso)
  fresh_until=$(_cache_iso_plus_days "$CURLING_RESEARCH_CACHE_TTL_DAYS")
  query_hash=$(printf '%s' "$query" | _cache_sha1)
  # First 200 chars of the answer, with newlines collapsed to spaces.
  summary=$(printf '%s' "$answer" | tr '\n' ' ' | cut -c1-200)
  jq -cn \
    --arg key "$key" \
    --arg ts "$ts" \
    --arg slugs "$slugs" \
    --arg query_hash "$query_hash" \
    --arg answer_summary "$summary" \
    --arg fresh_until "$fresh_until" \
    '{key:$key, ts:$ts, slugs:$slugs, query_hash:$query_hash, answer_summary:$answer_summary, fresh_until:$fresh_until}' \
    >> "$CURLING_RESEARCH_CACHE_FILE" || return 1
  return 0
}

# cache_purge_stale → drop entries with fresh_until < now. Rewrites the file.
cache_purge_stale() {
  [[ -f "$CURLING_RESEARCH_CACHE_FILE" ]] || return 0
  local now_iso
  now_iso=$(_cache_now_iso)
  local tmp
  tmp=$(mktemp)
  jq -c --arg now "$now_iso" 'select(.fresh_until > $now)' \
    "$CURLING_RESEARCH_CACHE_FILE" > "$tmp" 2>/dev/null || {
      rm -f "$tmp"
      return 1
    }
  mv "$tmp" "$CURLING_RESEARCH_CACHE_FILE"
  return 0
}
