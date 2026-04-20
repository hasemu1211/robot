#!/usr/bin/env bash
# promote.sh — move a child's wiki/skill/setting file up to the parent ~/robot/ scope.
#
# Usage:
#   promote.sh <child>/<relpath>              # e.g., datafactory/wiki/isaac_cache_volume.md
#   promote.sh <child>/<relpath> --dst <dir>  # override destination (default: ~/robot/wiki/)
#   promote.sh <child>/<relpath> --dry-run    # print plan without executing
#   promote.sh <child>/<relpath> --skip-scan  # skip value pre-flight
#
# Actions:
#   1. Pre-flight VALUE scan — count how many files (in OTHER children + parent) reference
#      keywords of the promoted file. Low count → may not be worth promoting yet.
#   2. Move the file from <child> to <dst> via `git mv` (history preserved within parent repo).
#      Note: if <child> is a symlink, `git mv` actually operates on the real-path repo.
#      Symlinked children therefore require a copy + git rm (fall back).
#   3. Append entry to ~/robot/wiki/INDEX.md (idempotent).
#   4. Commit in ~/robot/ with a conventional "promote:" message.

set -euo pipefail

PARENT="$HOME/robot"
DST_DEFAULT="$PARENT/wiki"

DRY_RUN=0
SKIP_SCAN=0
DST=""
SRC=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)   DRY_RUN=1; shift ;;
    --skip-scan) SKIP_SCAN=1; shift ;;
    --dst)       DST="$2"; shift 2 ;;
    -h|--help)
      sed -n '/^# Usage:/,/^# *4\./p' "$0" | sed 's/^# \?//'; exit 0
      ;;
    -*) echo "Unknown flag: $1" >&2; exit 2 ;;
    *)
      if [[ -z "$SRC" ]]; then SRC="$1"; shift
      else echo "Unexpected extra arg: $1" >&2; exit 2
      fi
      ;;
  esac
done

[[ -z "$SRC" ]] && { echo "Usage: $0 <child>/<relpath> [--dst <dir>] [--dry-run] [--skip-scan]" >&2; exit 2; }
[[ -z "$DST" ]] && DST="$DST_DEFAULT"

# Resolve absolute source path
SRC_FULL="$PARENT/$SRC"
if [[ ! -e "$SRC_FULL" ]]; then
  echo "ERROR: source not found: $SRC_FULL" >&2
  exit 2
fi

FNAME="$(basename "$SRC")"
DST_FULL="$DST/$FNAME"

echo "[promote] source: $SRC_FULL"
echo "[promote] destination: $DST_FULL"

if [[ -e "$DST_FULL" ]]; then
  echo "ERROR: destination already exists: $DST_FULL" >&2
  exit 2
fi

# --- Pre-flight VALUE scan ---
if [[ "$SKIP_SCAN" = 0 ]]; then
  echo "[promote] pre-flight: scanning how often concepts in '$FNAME' appear elsewhere..."
  # Extract headers-derived keywords (permit zero hits without aborting)
  KEYWORDS=$(awk '/^#{1,3} / { for(i=2;i<=NF;i++) print $i }' "$SRC_FULL" 2>/dev/null \
    | awk 'NF && !/^(the|a|an|and|or|of|for|to|in|이|그|저|의|및|또는)$/' \
    | head -10 | tr '\n' '|' | sed 's/|$//' || true)
  if [[ -n "$KEYWORDS" ]]; then
    # grep exits 1 on zero matches — guard via || true. wc -l always succeeds.
    HIT_COUNT=$(
      {
        grep -rnE "($KEYWORDS)" \
          "$PARENT/wiki" "$PARENT"/*/wiki \
          --include='*.md' --exclude-dir='.git' 2>/dev/null || true
      } | { grep -v "$SRC_FULL" || true; } | wc -l
    )
    echo "[promote] keyword hits in other wiki files: $HIT_COUNT"
    if [[ "$HIT_COUNT" -lt 3 ]]; then
      echo "[promote] WARN: low cross-reference ($HIT_COUNT < 3) — consider if this is truly global."
      echo "          (skip this warning with --skip-scan)"
    fi
  else
    echo "[promote] (no keywords extracted; scan skipped)"
  fi
fi

# --- Dry run exit ---
if [[ "$DRY_RUN" = 1 ]]; then
  echo "[promote] DRY: would git mv '$SRC_FULL' '$DST_FULL' and commit."
  echo "[promote] DRY: would append '- [$FNAME]($FNAME)' to $DST/INDEX.md if missing."
  exit 0
fi

# --- Execute move ---
# Prefer `git mv` in parent to preserve history within parent repo.
# For symlinked children, the file physically lives in another repo — fall back to cp+rm.
if [[ -L "$PARENT/${SRC%%/*}" ]]; then
  echo "[promote] child is symlink; using cp (original history stays in child repo)"
  cp "$SRC_FULL" "$DST_FULL"
  rm "$SRC_FULL"
  (cd "$PARENT/${SRC%%/*}" && git add -u)
  (cd "$PARENT" && git add "$DST_FULL")
else
  (cd "$PARENT" && git mv "$SRC" "${DST#$PARENT/}/$FNAME")
fi

# --- Update INDEX.md if missing ---
INDEX="$DST/INDEX.md"
if [[ -f "$INDEX" ]] && ! grep -q "$FNAME" "$INDEX"; then
  echo "[promote] appending to $INDEX"
  # Insert a new bullet under the "## 교훈" or "## Lessons" section (first match), else append to end
  if grep -qE '^## (교훈|Lessons)' "$INDEX"; then
    awk -v bullet="- [$FNAME]($FNAME) — promoted $(date -I)" '
      /^## (교훈|Lessons)/ {print; getline; print; print bullet; next}
      {print}
    ' "$INDEX" > /tmp/index.md && mv /tmp/index.md "$INDEX"
  else
    echo "" >> "$INDEX"
    echo "- [$FNAME]($FNAME) — promoted $(date -I)" >> "$INDEX"
  fi
  (cd "$PARENT" && git add "$INDEX")
fi

# --- Commit ---
COMMIT_MSG="promote: $FNAME from $(dirname "$SRC") to global wiki"
(cd "$PARENT" && git -c user.name="${GIT_AUTHOR_NAME:-$(git config user.name || echo unknown)}" \
                       -c user.email="${GIT_AUTHOR_EMAIL:-$(git config user.email || echo unknown@localhost)}" \
                       commit -m "$COMMIT_MSG")

echo "[promote] DONE — committed in $PARENT"
echo "[promote] reminder: if the child repo still holds the file pre-symlink, delete it there too."
