#!/usr/bin/env bash
# fallback-fetch.sh — recover URLs that NotebookLM's URL ingester refuses
# (Springer paywalls, anti-bot walls, login walls, cookie walls).
#
# Strategy: fetch the page with curl using a browser-like User-Agent, strip
# HTML to plain text, prepend a header preserving the original citation URL,
# and submit the result as a `--type text` source. This bypasses NotebookLM's
# URL fetcher entirely while keeping the URL discoverable in the source body.
#
# Usage:
#   fallback-fetch.sh <slug> <URL> [<URL>...]
#       Fetch one or more explicit URLs into the slug's notebook.
#
#   fallback-fetch.sh --auto <slug>
#       Diff the slug's MD URLs against the notebook's existing sources,
#       fetch+submit every URL that's missing.
#
#   fallback-fetch.sh --auto-all
#       Run --auto across every notebook in registry.json.
#
#   fallback-fetch.sh --dry-run <slug> <URL> [<URL>...]
#       Same as the explicit form but prints the would-be `notebooklm source
#       add` invocation with a `DRY:` prefix instead of actually calling it.
#       Useful for smoke testing without burning credits.
#
#   fallback-fetch.sh --help
#       Show this help.
#
# Requirements: curl, jq, python3, notebooklm (already required by skill).
# Compatible with macOS bash 3.2.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTEBOOKS_DIR="$SKILL_DIR/notebooks"
REGISTRY="$SKILL_DIR/registry.json"

UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'
MAX_BYTES=51200    # 50 KB cap on extracted plain text
CURL_TIMEOUT=30
INTER_NB_DELAY=2   # seconds between notebooks in --auto-all

SUCCEEDED=0
FAILED=0
DRY_RUN=0

# ---- cleanup ----------------------------------------------------------------
TMPFILES=()
cleanup_tmpfiles() {
  local f
  for f in "${TMPFILES[@]:-}"; do
    if [[ -n "${f:-}" && -f "$f" ]]; then
      rm -f "$f" || true
    fi
  done
  return 0
}
trap cleanup_tmpfiles EXIT

# ---- usage / help -----------------------------------------------------------
print_help() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# ---- registry lookup --------------------------------------------------------
lookup_notebook_id() {
  local slug="$1"
  jq -r --arg s "$slug" '.notebooks[] | select(.slug == $s) | .notebook_id' "$REGISTRY" 2>/dev/null
}

list_all_slugs() {
  jq -r '.notebooks[].slug' "$REGISTRY" 2>/dev/null
}

# ---- HTML → text via embedded python3 ---------------------------------------
# Reads HTML on stdin, writes plain text on stdout. Also extracts the <title>
# tag value to a sidecar file path passed as $1 (or /dev/null if blank).
html_to_text() {
  local title_out="${1:-/dev/null}"
  python3 - "$title_out" <<'PY'
import sys
import re
from html.parser import HTMLParser
from html import unescape

title_path = sys.argv[1]
data = sys.stdin.read()

# Quick-strip script/style blocks before parsing — prevents JS bodies leaking
# into the text. Case-insensitive, dotall.
data = re.sub(r'(?is)<script[^>]*>.*?</script>', ' ', data)
data = re.sub(r'(?is)<style[^>]*>.*?</style>', ' ', data)
data = re.sub(r'(?is)<noscript[^>]*>.*?</noscript>', ' ', data)

class Extractor(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.in_title = False
        self.title = []
        self.skip_depth = 0  # nested <script>/<style> guard (defensive)

    def handle_starttag(self, tag, attrs):
        if tag == 'title':
            self.in_title = True
        elif tag in ('script', 'style', 'noscript'):
            self.skip_depth += 1
        elif tag in ('br', 'p', 'div', 'li', 'tr', 'h1', 'h2', 'h3',
                     'h4', 'h5', 'h6', 'section', 'article'):
            self.parts.append('\n')

    def handle_endtag(self, tag):
        if tag == 'title':
            self.in_title = False
        elif tag in ('script', 'style', 'noscript') and self.skip_depth > 0:
            self.skip_depth -= 1
        elif tag in ('p', 'div', 'li', 'tr', 'h1', 'h2', 'h3',
                     'h4', 'h5', 'h6', 'section', 'article'):
            self.parts.append('\n')

    def handle_data(self, data):
        if self.skip_depth > 0:
            return
        if self.in_title:
            self.title.append(data)
        else:
            self.parts.append(data)

ex = Extractor()
try:
    ex.feed(data)
except Exception:
    # Malformed HTML — fall back to a regex strip of remaining tags.
    pass

text = ''.join(ex.parts)
# Collapse runs of whitespace within a line, then collapse blank-line runs.
lines = []
for line in text.splitlines():
    line = re.sub(r'[ \t ]+', ' ', line).strip()
    lines.append(line)
out = []
prev_blank = False
for line in lines:
    if not line:
        if prev_blank:
            continue
        prev_blank = True
    else:
        prev_blank = False
    out.append(line)
sys.stdout.write('\n'.join(out).strip() + '\n')

if title_path and title_path != '/dev/null':
    title = unescape(' '.join(ex.title)).strip()
    title = re.sub(r'\s+', ' ', title)
    with open(title_path, 'w') as fh:
        fh.write(title)
PY
}

# ---- fallback for title when <title> is missing -----------------------------
url_to_synthetic_title() {
  local url="$1"
  # host + last non-empty path segment
  local host path basename
  host="${url#*://}"; host="${host%%/*}"
  path="${url#*://*/}"
  if [[ "$path" == "$url" ]]; then
    path=""
  fi
  basename="${path##*/}"
  basename="${basename%%\?*}"
  if [[ -n "$basename" ]]; then
    printf '%s — %s' "$host" "$basename"
  else
    printf '%s' "$host"
  fi
}

# ---- single URL pipeline ----------------------------------------------------
# Args: nb_id url
# Returns 0 on success, non-zero on failure. Prints status line.
fetch_and_submit() {
  local nb_id="$1" url="$2"

  local html_tmp text_tmp title_tmp final_tmp
  html_tmp=$(mktemp /tmp/curling-research-fallback-html.XXXXXX) || return 1
  text_tmp=$(mktemp /tmp/curling-research-fallback-text.XXXXXX) || return 1
  title_tmp=$(mktemp /tmp/curling-research-fallback-title.XXXXXX) || return 1
  final_tmp=$(mktemp /tmp/curling-research-fallback-XXXXXX.txt) || return 1
  TMPFILES+=("$html_tmp" "$text_tmp" "$title_tmp" "$final_tmp")

  # 1) curl the page
  local curl_err
  if ! curl_err=$(curl -sS --fail -L --max-time "$CURL_TIMEOUT" \
                       -A "$UA" \
                       -o "$html_tmp" \
                       "$url" 2>&1); then
    printf '[!] %s → curl failed: %s\n' "$url" "${curl_err%%$'\n'*}"
    return 1
  fi

  if [[ ! -s "$html_tmp" ]]; then
    printf '[!] %s → empty response\n' "$url"
    return 1
  fi

  # 2) HTML → text (and capture <title>)
  if ! html_to_text "$title_tmp" <"$html_tmp" >"$text_tmp" 2>/dev/null; then
    printf '[!] %s → html-to-text extraction failed\n' "$url"
    return 1
  fi

  if [[ ! -s "$text_tmp" ]]; then
    printf '[!] %s → no text extracted\n' "$url"
    return 1
  fi

  # 3) determine title
  local title
  title=$(cat "$title_tmp" 2>/dev/null || true)
  if [[ -z "$title" ]]; then
    title=$(url_to_synthetic_title "$url")
  fi

  # 4) build final document — header + truncated text
  local timestamp
  timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  {
    printf '# %s\n\n' "$title"
    printf 'Source URL: %s\n' "$url"
    printf 'Fetched: %s\n' "$timestamp"
    printf 'Fallback method: curl + HTML text extraction (NotebookLM URL ingester blocked)\n\n'
    printf -- '---\n\n'
    # Truncate to MAX_BYTES of body text (header is small + bounded).
    head -c "$MAX_BYTES" "$text_tmp"
    # Trailing newline so cat doesn't glue lines.
    printf '\n'
  } >"$final_tmp"

  local extracted_bytes
  extracted_bytes=$(wc -c <"$final_tmp" | tr -d ' ')

  # 5) submit (or dry-run print)
  local source_title="${title} (fallback)"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'DRY: notebooklm source add --type text -n %s %s --title %q\n' \
      "$nb_id" "$final_tmp" "$source_title"
    printf '[+] %s → %s bytes extracted, would submit as text\n' "$url" "$extracted_bytes"
    return 0
  fi

  local add_err
  if ! add_err=$(notebooklm source add --type text -n "$nb_id" "$final_tmp" \
                   --title "$source_title" 2>&1 >/dev/null); then
    printf '[!] %s → notebooklm source add failed: %s\n' "$url" "${add_err%%$'\n'*}"
    return 1
  fi

  printf '[+] %s → %s bytes extracted, submitted as text\n' "$url" "$extracted_bytes"
  return 0
}

# ---- iterate URLs in a notebook for --auto ---------------------------------
auto_for_slug() {
  local slug="$1"
  local md="$NOTEBOOKS_DIR/$slug.md"
  local nb_id
  nb_id=$(lookup_notebook_id "$slug")

  if [[ -z "$nb_id" || "$nb_id" == "null" ]]; then
    printf '[!] slug %s → no notebook_id in registry; skipping\n' "$slug"
    return 1
  fi
  if [[ ! -f "$md" ]]; then
    printf '[!] slug %s → %s not found; skipping\n' "$slug" "$md"
    return 1
  fi

  printf '== %s (%s) ==\n' "$slug" "$nb_id"

  # Pull URLs from MD.
  local md_urls
  md_urls=$(grep -oE 'https?://[^[:space:]<>")]+' "$md" \
              | sed -E 's/[.,;:!?]+$//' \
              | sort -u || true)

  if [[ -z "$md_urls" ]]; then
    printf '   no URLs found in %s\n' "$md"
    return 0
  fi

  # Fetch existing sources from notebook.
  local existing
  existing=$(notebooklm source list --json -n "$nb_id" 2>/dev/null \
              | jq -r '[.sources // .[] // empty | .. | objects | (.url? // .source_url? // empty)] | unique | .[]' 2>/dev/null \
              || true)

  # Diff (canonicalize lightly: strip trailing slash + fragment).
  local md_canon existing_canon
  md_canon=$(printf '%s\n' "$md_urls" \
              | sed -E 's|#.*$||; s|/+$||' \
              | sort -u)
  existing_canon=$(printf '%s\n' "$existing" \
              | sed -E 's|#.*$||; s|/+$||' \
              | sort -u)

  local pending
  pending=$(comm -23 \
              <(printf '%s' "$md_canon" | grep -v '^$') \
              <(printf '%s' "$existing_canon" | grep -v '^$') || true)

  if [[ -z "$pending" ]]; then
    printf '   no missing URLs\n'
    return 0
  fi

  local count
  count=$(printf '%s\n' "$pending" | grep -c . || true)
  printf '   %s URL(s) missing — running fallback fetch\n' "$count"

  local url
  while IFS= read -r url; do
    [[ -z "$url" ]] && continue
    if fetch_and_submit "$nb_id" "$url"; then
      SUCCEEDED=$((SUCCEEDED+1))
    else
      FAILED=$((FAILED+1))
    fi
  done <<< "$pending"
}

# ---- main -------------------------------------------------------------------
main() {
  if [[ $# -eq 0 ]]; then
    print_help
    exit 1
  fi

  # Pre-scan for --dry-run flag (can appear anywhere).
  local args=()
  local a
  for a in "$@"; do
    case "$a" in
      --dry-run) DRY_RUN=1 ;;
      *) args+=("$a") ;;
    esac
  done
  set -- "${args[@]:-}"

  if [[ $# -eq 0 ]]; then
    print_help
    exit 1
  fi

  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    --auto)
      shift
      if [[ $# -ne 1 ]]; then
        printf 'Usage: fallback-fetch.sh --auto <slug>\n' >&2
        exit 2
      fi
      auto_for_slug "$1"
      ;;
    --auto-all)
      local slug
      while IFS= read -r slug; do
        [[ -z "$slug" ]] && continue
        auto_for_slug "$slug" || true
        sleep "$INTER_NB_DELAY"
      done < <(list_all_slugs)
      ;;
    --*)
      printf 'unknown flag: %s\n' "$1" >&2
      print_help
      exit 2
      ;;
    *)
      # Explicit form: <slug> <URL> [<URL>...]
      if [[ $# -lt 2 ]]; then
        printf 'Usage: fallback-fetch.sh <slug> <URL> [<URL>...]\n' >&2
        exit 2
      fi
      local slug="$1"; shift
      local nb_id
      nb_id=$(lookup_notebook_id "$slug")
      if [[ -z "$nb_id" || "$nb_id" == "null" ]]; then
        printf 'unknown slug: %s (not in %s)\n' "$slug" "$REGISTRY" >&2
        exit 2
      fi
      printf '== %s (%s) ==\n' "$slug" "$nb_id"
      local url
      for url in "$@"; do
        if fetch_and_submit "$nb_id" "$url"; then
          SUCCEEDED=$((SUCCEEDED+1))
        else
          FAILED=$((FAILED+1))
        fi
      done
      ;;
  esac

  printf '\n%s succeeded, %s failed\n' "$SUCCEEDED" "$FAILED"
  if [[ "$FAILED" -gt 0 && "$SUCCEEDED" -eq 0 ]]; then
    exit 1
  fi
}

main "$@"
