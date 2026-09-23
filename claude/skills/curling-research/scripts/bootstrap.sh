#!/usr/bin/env bash
# bootstrap.sh — create the 12 NotebookLM notebooks and seed each with its URL list.
#
# Usage:
#   bootstrap.sh              # interactive (asks before each notebook)
#   bootstrap.sh --dry-run    # show what would happen, write nothing
#   bootstrap.sh --yes        # non-interactive (CI / repeat runs)
#   bootstrap.sh --slug 03-sweeping --refresh-card  # rebuild one card from index
#
# After bootstrap completes, registry.json is populated with notebook IDs and
# scripts/build-cards.py is re-run to inject those IDs into the per-notebook
# Agent Card files.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTEBOOKS_DIR="$SKILL_DIR/notebooks"
REGISTRY="$SKILL_DIR/registry.json"
INDEX="$SKILL_DIR/agent-cards/index.json"

DRY_RUN=0
YES=0
ONLY_SLUG=""
REFRESH_CARD_ONLY=0
CONCURRENCY=4
ADD_TIMEOUT=90

# Domains where NotebookLM's scraper has been observed to fail permanently
# (paywall / login wall / aggressive bot detection). URLs whose host suffix
# matches an entry here are silently skipped in the seeding loop so we don't
# keep prompting on re-runs. Add to this list when a domain proves consistently
# unscrape-able. Match is host-suffix only (not substring of full URL) — see
# is_known_bad_url() below: an entry like `amazon.com` matches `www.amazon.com`
# and `smile.amazon.com`, but never `not-amazon.com` or `amazon.com.attacker`.
# Only add domains whose failure is structural (anti-bot, paywall, login wall);
# transient timeouts (worldcurling.org, olympics.com, scitepress.org,
# wsb.wharton.upenn.edu) do NOT belong here.
KNOWN_BAD_DOMAINS=(
  # Academic / journal paywalls (institutional auth required)
  "ieeexplore.ieee.org"
  "link.springer.com"
  "onlinelibrary.wiley.com"
  "science.org"
  "sciencedirect.com"

  # News / publisher paywalls and cookie walls
  "csmonitor.com"
  "scotsman.com"
  "theconversation.com"

  # Login / account walls
  "amazon.com"
  "oreilly.com"

  # Anti-bot / scraper-blocking storefronts and game-media sites
  "gamezone.com"
  "giantbomb.com"
  "metacritic.com"
  "mobygames.com"
  "operationsports.com"
  "siliconera.com"
  "t-minuscountdown.com"
  "thepixelempire.net"
  "xbox.com"

  # Cookie consent walls that block headless fetch
  "playdoublescurling.com"
)

# Tmpdirs to clean up on exit (registered as we go; bash 3.2 has no
# associative arrays, so a parallel array of paths is the simplest model).
CLEANUP_TMPDIRS=()
cleanup_tmpdirs() {
  local d
  for d in "${CLEANUP_TMPDIRS[@]:-}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup_tmpdirs EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y) YES=1; shift ;;
    --slug) ONLY_SLUG="$2"; shift 2 ;;
    --refresh-card) REFRESH_CARD_ONLY=1; shift ;;
    --concurrency) CONCURRENCY="$2"; shift 2 ;;
    --timeout) ADD_TIMEOUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

if ! command -v notebooklm >/dev/null 2>&1; then
  echo "error: notebooklm CLI not on PATH" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required (brew install jq)" >&2
  exit 1
fi

# Pick a timeout binary: GNU coreutils' `timeout` (Linux) or `gtimeout` (macOS via `brew install coreutils`).
# Required for hung-RPC protection — without it, one stuck notebooklm RPC stalls the entire seeding pass.
if command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
elif command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
else
  echo "error: install GNU coreutils (brew install coreutils) for gtimeout — required for hung-RPC protection" >&2
  exit 1
fi

confirm() {
  [[ "$YES" == "1" ]] && return 0
  read -r -p "$1 [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

extract_urls() {
  # Extract every http(s) URL from a notebook source MD. Different research
  # agents emitted four different conventions across the 12 notebooks:
  #   - **URL:** https://...        (bolded marker)
  #   - URL: https://...            (plain marker)
  #   - <https://...>               (markdown autolink — bare)
  #   - [label](https://...)        (markdown link reference)
  # Rather than chase every variant, grab every URL anywhere in the file and
  # clean the edges. The MDs are pure source lists (not prose) so false
  # positives are negligible. Output is sorted-unique.
  local file="$1"
  grep -oE 'https?://[^[:space:]<>")]+' "$file" \
    | sed -E 's/[.,;:!?]+$//' \
    | sort -u
}

# Canonicalize a URL for diff comparison: strip fragment, trailing slash,
# lowercase scheme+host. Path/query are case-preserved.
canonicalize_url() {
  local u="$1"
  local rest scheme host path
  u="${u%#*}"           # strip fragment
  u="${u%/}"            # strip trailing slash
  # Split scheme://rest
  if [[ "$u" == *"://"* ]]; then
    scheme="${u%%://*}"
    rest="${u#*://}"
    scheme=$(printf '%s' "$scheme" | tr '[:upper:]' '[:lower:]')
    if [[ "$rest" == *"/"* ]]; then
      host="${rest%%/*}"
      path="/${rest#*/}"
    else
      host="$rest"
      path=""
    fi
    host=$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')
    printf '%s://%s%s' "$scheme" "$host" "$path"
  else
    printf '%s' "$u"
  fi
}

# Extract host from a URL (no scheme, no path).
url_host() {
  local u="$1"
  u="${u#*://}"         # strip scheme
  u="${u%%/*}"          # strip path
  printf '%s' "$u" | tr '[:upper:]' '[:lower:]'
}

# Match a URL's host against KNOWN_BAD_DOMAINS via exact-or-suffix match.
# Returns 0 if bad, 1 if ok.
is_known_bad_url() {
  local url="$1"
  local h
  h=$(url_host "$url")
  local d
  for d in "${KNOWN_BAD_DOMAINS[@]}"; do
    if [[ "$h" == "$d" || "$h" == *".$d" ]]; then
      return 0
    fi
  done
  return 1
}

# Atomic registry update: take a jq filter, apply it, mv into place under a
# directory-based lock so concurrent invocations can't shred the file.
update_registry() {
  local filter="$1"; shift
  local lock="$REGISTRY.lock"
  local tries=0
  while ! mkdir "$lock" 2>/dev/null; do
    tries=$((tries+1))
    if [[ "$tries" -ge 50 ]]; then
      echo "error: could not acquire $lock after 50 tries" >&2
      return 1
    fi
    sleep 0.1
  done
  # shellcheck disable=SC2064
  trap "rmdir '$lock' 2>/dev/null || true" RETURN
  local tmp
  tmp=$(mktemp)
  if ! jq "$@" "$filter" "$REGISTRY" > "$tmp"; then
    rm -f "$tmp"
    rmdir "$lock" 2>/dev/null || true
    trap - RETURN
    return 1
  fi
  mv "$tmp" "$REGISTRY"
  rmdir "$lock" 2>/dev/null || true
  trap - RETURN
}

slugs=()
titles=()
files=()
while IFS= read -r f; do
  base="$(basename "$f" .md)"
  [[ -n "$ONLY_SLUG" && "$base" != "$ONLY_SLUG" ]] && continue
  title="$(head -n1 "$f" | sed 's/^# //')"
  slugs+=("$base")
  titles+=("$title")
  files+=("$f")
done < <(ls "$NOTEBOOKS_DIR"/*.md | sort)

if [[ ${#slugs[@]} -eq 0 ]]; then
  echo "error: no notebooks found in $NOTEBOOKS_DIR" >&2
  exit 1
fi

# Initialize registry if missing
if [[ ! -f "$REGISTRY" ]]; then
  echo '{"version":"1.0.0","notebooks":[]}' > "$REGISTRY"
fi

if [[ "$REFRESH_CARD_ONLY" == "1" ]]; then
  echo "Refreshing Agent Cards from index.json + registry.json…"
  python3 "$SKILL_DIR/scripts/build-cards.py" --registry "$REGISTRY"
  exit 0
fi

echo "About to create/update ${#slugs[@]} NotebookLM notebooks."
echo "Dry run: $([[ "$DRY_RUN" == "1" ]] && echo YES || echo NO)"
echo
for i in "${!slugs[@]}"; do
  printf "  %2d. %-30s %s\n" "$((i+1))" "${slugs[$i]}" "${titles[$i]}"
done
echo

confirm "Proceed?" || { echo "aborted"; exit 0; }

# Per-notebook seed function. Returns nothing; manages its own tmpdir via
# RETURN trap (which DOES fire inside functions on bash 3.2).
seed_notebook() {
  local slug="$1"
  local title="$2"
  local file="$3"
  local notebook_title="Curling Research — $title"

  echo
  echo "──────── $slug ($title) ────────"

  # Has this slug already been bootstrapped (in registry)?
  local existing_id nb_id
  existing_id=$(jq -r --arg s "$slug" '.notebooks[] | select(.slug==$s) | .notebook_id // empty' "$REGISTRY")
  if [[ -n "$existing_id" ]]; then
    echo "  already in registry: $existing_id (skipping create)"
    nb_id="$existing_id"
  elif [[ "$DRY_RUN" == "1" ]]; then
    echo "  DRY: notebooklm create \"$notebook_title\""
    nb_id="DRY-RUN-$slug"
  else
    # Look up by exact title in case a previous run created it but failed to record
    existing_id=$(notebooklm list --json 2>/dev/null \
      | jq -r --arg t "$notebook_title" '.notebooks[]? | select(.title==$t) | .id' \
      | head -n1)

    if [[ -n "$existing_id" && "$existing_id" != "null" ]]; then
      echo "  found existing notebook on account: $existing_id (recovering)"
      nb_id="$existing_id"
    else
      confirm "  create notebook \"$notebook_title\"?" || { echo "  skipped"; return 0; }
      notebooklm create "$notebook_title" >/dev/null 2>&1 || true
      # Resolve ID via list lookup (works regardless of create's output shape)
      nb_id=$(notebooklm list --json 2>/dev/null \
        | jq -r --arg t "$notebook_title" '.notebooks[]? | select(.title==$t) | .id' \
        | head -n1)
      if [[ -z "$nb_id" || "$nb_id" == "null" ]]; then
        echo "  failed to locate notebook by title after create" >&2
        exit 1
      fi
      echo "  created: $nb_id"
    fi

    update_registry \
      '.notebooks |= (map(select(.slug != $s)) + [{slug:$s, title:$title, notebook_id:$id, sources:[]}])' \
      --arg s "$slug" --arg id "$nb_id" --arg title "$title"
  fi

  local urls url_count
  urls=$(extract_urls "$file")
  url_count=$(printf '%s' "$urls" | grep -c . || true)
  echo "  $url_count URLs found in $file"

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '%s\n' "$urls" | head -3 | sed "s|^|    DRY: notebooklm source add -n $nb_id |"
    [[ "$url_count" -gt 3 ]] && echo "    DRY: (… $((url_count-3)) more …)"
    return 0
  fi

  # Idempotency: fetch existing source URLs and skip them.
  local existing_urls existing_count
  existing_urls=$(notebooklm source list --json -n "$nb_id" 2>/dev/null \
    | jq -r '[.sources // .[] // empty | .. | objects | (.url? // .source_url? // empty)] | unique | .[]' 2>/dev/null \
    || true)
  existing_count=$(printf '%s\n' "$existing_urls" | grep -c . || true)
  [[ "$existing_count" -gt 0 ]] && echo "  notebook already has $existing_count source(s); will skip duplicates"

  # Canonicalize both sides before diffing so trailing slashes / case / fragments
  # don't cause spurious "new" URLs.
  local urls_canon existing_canon
  urls_canon=""
  while IFS= read -r u; do
    [[ -z "$u" ]] && continue
    urls_canon+="$(canonicalize_url "$u")"$'\n'
  done <<< "$urls"
  existing_canon=""
  while IFS= read -r u; do
    [[ -z "$u" ]] && continue
    existing_canon+="$(canonicalize_url "$u")"$'\n'
  done <<< "$existing_urls"

  local pending
  pending=$(comm -23 \
    <(printf '%s' "$urls_canon" | grep -v '^$' | sort -u) \
    <(printf '%s' "$existing_canon" | grep -v '^$' | sort -u))

  # Filter known-bad domains (NotebookLM scraper can't ingest these — paywalls/bot-walls)
  local filtered="" skipped_bad=0 url
  while IFS= read -r url; do
    [[ -z "$url" ]] && continue
    if is_known_bad_url "$url"; then
      skipped_bad=$((skipped_bad+1))
    else
      filtered+="$url"$'\n'
    fi
  done <<< "$pending"
  pending="${filtered%$'\n'}"
  local pending_count
  pending_count=$(printf '%s\n' "$pending" | grep -c . || true)

  [[ "$skipped_bad" -gt 0 ]] && echo "  skipping $skipped_bad URL(s) on known-paywalled domains (see KNOWN_BAD_DOMAINS in bootstrap.sh)"

  if [[ "$pending_count" -eq 0 ]]; then
    echo "  no remaining seedable URLs — nothing to do"
    return 0
  fi

  echo "  $pending_count of $url_count URLs are new and scrape-eligible"
  confirm "  add them now (concurrency=$CONCURRENCY, timeout=${ADD_TIMEOUT}s)?" || { echo "  skipped seeding"; return 0; }

  # Per-notebook tmpdir for worker result files. Cleaned up on function return.
  local log_dir
  log_dir=$(mktemp -d)
  CLEANUP_TMPDIRS+=("$log_dir")
  # shellcheck disable=SC2064
  trap "rm -rf '$log_dir'" RETURN

  # File-based result transport: each worker writes
  #   $log_dir/<sha>.status  (one line: "+|! <url>")
  #   $log_dir/<sha>.err     (stderr head, on failure only)
  # xargs runs to completion with stdout/stderr discarded — no consumer pipe,
  # so a downstream cat-on-missing-file can't SIGPIPE the workers.
  #
  # The worker script is intentionally permissive: it never lets a single URL
  # failure escalate to a nonzero exit (we capture failure via the .status
  # file), so xargs never sees a nonzero worker exit and never aborts siblings.
  printf '%s\n' "$pending" | grep -v '^$' \
    | xargs -P "$CONCURRENCY" -I@ bash -c '
        set +e
        url="$1"
        nb_id="$2"
        timeout_secs="$3"
        log_dir="$4"
        timeout_bin="$5"
        sha=$(printf "%s" "$url" | shasum | cut -d" " -f1)
        status_path="$log_dir/$sha.status"
        err_path="$log_dir/$sha.err"
        # Drop --type url so notebooklm auto-detects youtube vs url.
        # Forcing url-mode on a youtube.com/watch link rejects silently.
        if [[ -n "$timeout_bin" ]]; then
          err=$("$timeout_bin" "${timeout_secs}s" notebooklm source add -n "$nb_id" "$url" 2>&1 >/dev/null)
          rc=$?
        else
          err=$(notebooklm source add -n "$nb_id" "$url" 2>&1 >/dev/null)
          rc=$?
        fi
        if [[ $rc -eq 0 ]]; then
          printf "+ %s\n" "$url" > "$status_path.tmp" && mv "$status_path.tmp" "$status_path"
        else
          # Write err first so consumer reading after .status appears never
          # hits a missing-file race.
          printf "%s\n" "$err" | head -n2 > "$err_path"
          printf "! %s\n" "$url" > "$status_path.tmp" && mv "$status_path.tmp" "$status_path"
        fi
        exit 0
      ' _ @ "$nb_id" "$ADD_TIMEOUT" "$log_dir" "$TIMEOUT_BIN" \
    >/dev/null 2>&1 || true

  # Summarize from result files. No pipe to a consumer = no SIGPIPE.
  local added_local=0 failed_local=0 f kind status_url err_file err_line
  for f in "$log_dir"/*.status; do
    [[ -f "$f" ]] || continue
    # Read first line only, split into kind + url
    IFS= read -r line < "$f" || true
    kind="${line:0:1}"
    status_url="${line:2}"
    if [[ "$kind" == "+" ]]; then
      added_local=$((added_local+1))
      printf "    + %s\n" "$status_url"
    else
      err_file="${f%.status}.err"
      err_line=""
      [[ -f "$err_file" ]] && err_line=$(head -n1 "$err_file")
      failed_local=$((failed_local+1))
      printf "    ! %s\n        %s\n" "$status_url" "$err_line" >&2
    fi
  done
  echo "  $added_local added, $failed_local failed"

  local added_now
  added_now=$(notebooklm source list --json -n "$nb_id" 2>/dev/null \
    | jq -r '[.sources // .[] // empty | .. | objects | (.url? // .source_url? // empty)] | unique | length' 2>/dev/null \
    || echo "?")
  echo "  notebook now has $added_now source(s)"
}

for i in "${!slugs[@]}"; do
  seed_notebook "${slugs[$i]}" "${titles[$i]}" "${files[$i]}"
done

echo
echo "Refreshing Agent Cards from registry.json…"
python3 "$SKILL_DIR/scripts/build-cards.py" --registry "$REGISTRY"

echo
echo "Done. Registry: $REGISTRY"
echo "Test: $SKILL_DIR/scripts/ask 02-physics \"What does the literature say about scratch-guidance theory?\""
