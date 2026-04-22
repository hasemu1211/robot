#!/usr/bin/env bash
# hook-validate-edit.sh — PostToolUse validator for Edit/Write in robot parent repo.
#
# Responsibilities:
#   1. bash -n  on .sh files
#   2. YAML frontmatter lint on .md files that begin with '---'
#
# On failure: emits JSON on stdout with hookSpecificOutput.additionalContext so
# Claude sees a system-reminder-style warning inline. Does NOT block the edit.
#
# Reads Claude Code hook JSON from stdin (tool_input.file_path).
# Silent success (exit 0, no JSON) so normal edits aren't noisy.
#
# Dependencies: jq, python3 (for yaml parsing — stdlib only, no PyYAML required).
set -u

# Read hook payload (Claude Code passes JSON on stdin)
payload="$(cat)"

# Extract file path; bail silently on any extraction error
file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[[ -z "$file" ]] && exit 0
[[ -f "$file" ]] || exit 0  # Write can delete in rare cases; skip if missing

warn=""

case "$file" in
  *.sh)
    if ! err="$(bash -n "$file" 2>&1)"; then
      warn="bash -n failed on $file:\n$err"
    fi
    ;;
  *.md)
    # Only lint if file opens with '---' (frontmatter present)
    if head -1 "$file" 2>/dev/null | grep -q '^---$'; then
      if ! err="$(python3 - <<PY 2>&1
import sys
try:
    import yaml
except ImportError:
    # PyYAML not available; do a permissive structural check only.
    data = open("$file").read()
    parts = data.split("---", 2)
    if len(parts) < 3:
        print("frontmatter unterminated (missing closing '---')")
        sys.exit(1)
    sys.exit(0)
else:
    data = open("$file").read()
    parts = data.split("---", 2)
    if len(parts) < 3:
        print("frontmatter unterminated (missing closing '---')")
        sys.exit(1)
    try:
        fm = yaml.safe_load(parts[1])
        if not isinstance(fm, dict):
            print("frontmatter is not a YAML mapping")
            sys.exit(1)
    except yaml.YAMLError as e:
        print(f"YAML parse error: {e}")
        sys.exit(1)
PY
      )"; then
        warn="frontmatter lint failed on $file:\n$err"
      fi
    fi
    ;;
  *)
    exit 0  # Unrelated file; silent
    ;;
esac

if [[ -n "$warn" ]]; then
  # Emit hookSpecificOutput so Claude sees the warning. Do NOT block (exit 0).
  printf '%s' "$warn" | jq -Rs --arg event "PostToolUse" '{
    hookSpecificOutput: {
      hookEventName: $event,
      additionalContext: ("[hook-validate-edit] " + .)
    }
  }'
fi

exit 0
