#!/usr/bin/env bash
# merge-dotfiles.sh — Interactive helper for reconciling existing user dotfiles with ~/robot/dotfiles/.
#
# Complements install.sh --step=dotfiles (which does backup → symlink automatically).
# Use this when you want per-file decisions instead of wholesale backup.
#
# Usage:
#   merge-dotfiles.sh                    # interactive on all managed dotfiles
#   merge-dotfiles.sh --file=<name>      # limit to one (wezterm|tmux|xprofile|wezterm-kb)
#   merge-dotfiles.sh --dry-run          # print what would happen, no writes

set -euo pipefail

# ── ROBOT_ROOT resolver (shared contract; see install.sh / doctor.sh) ──
resolve_robot_root() {
  if [[ -n "${ROBOT_ROOT:-}" ]]; then
    echo "$ROBOT_ROOT"; return 0
  fi
  local anchor
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    anchor="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  else
    anchor="$PWD"
  fi
  if git -C "$anchor" rev-parse --show-toplevel &>/dev/null; then
    git -C "$anchor" rev-parse --show-toplevel; return 0
  fi
  echo "ERROR: ROBOT_ROOT 미정 — env var 세팅 또는 git repo 내에서 실행" >&2
  return 2
}

ROBOT_ROOT=$(resolve_robot_root)
DRY_RUN=0
FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --file=*)  FILTER="${1#*=}"; shift ;;
    -h|--help)
      sed -n '/^# merge-dotfiles/,/^# Usage:/p;/^# Usage:/,/^$/p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ── Color helpers ──
if [ -t 1 ]; then
  BOLD=$(tput bold); DIM=$(tput dim); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); RED=$(tput setaf 1); BLUE=$(tput setaf 4); NC=$(tput sgr0)
else
  BOLD=""; DIM=""; GREEN=""; YELLOW=""; RED=""; BLUE=""; NC=""
fi

# ── Managed dotfiles (source relative to ROBOT_ROOT) ──
# Format: tag|source|target
MAPPING=(
  "wezterm|dotfiles/wezterm.lua|$HOME/.config/wezterm/wezterm.lua"
  "wezterm-kb|dotfiles/wezterm-KEYBINDINGS.md|$HOME/.config/wezterm/KEYBINDINGS.md"
  "tmux|dotfiles/tmux.conf|$HOME/.tmux.conf"
  "xprofile|dotfiles/xprofile|$HOME/.xprofile"
)

say() { printf "%b\n" "$*"; }
run() { [[ "$DRY_RUN" = 1 ]] && say "  ${DIM}DRY:${NC} $*" || eval "$@"; }

# Backup existing with timestamp
backup_file() {
  local target="$1"
  local ts; ts=$(date -u +%Y%m%dT%H%M%SZ)
  local bak="${target}.pre-robot.${ts}.bak"
  say "  ${YELLOW}backup:${NC} $target → $bak"
  run "mv \"$target\" \"$bak\""
}

# Prompt for one file
handle_file() {
  local tag="$1" src_rel="$2" target="$3"
  local src="$ROBOT_ROOT/$src_rel"

  say "${BOLD}═══ $tag ═══${NC}"
  say "  source: $src"
  say "  target: $target"

  # Source missing: skip
  if [[ ! -e "$src" ]]; then
    say "  ${RED}[MISSING]${NC} repo source not found — run install.sh --step=dotfiles first or check clone integrity"
    return 0
  fi

  # Target missing: simple symlink
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    say "  ${GREEN}[NEW]${NC} target absent → create symlink"
    run "mkdir -p \"$(dirname \"$target\")\""
    run "ln -sf \"$src\" \"$target\""
    return 0
  fi

  # Already correctly symlinked: skip
  if [[ -L "$target" ]] && [[ "$(readlink -f "$target")" == "$(readlink -f "$src")" ]]; then
    say "  ${GREEN}[OK]${NC} already symlinked to repo source — no action"
    return 0
  fi

  # Diff summary
  local diff_lines
  diff_lines=$(diff -u "$target" "$src" 2>/dev/null | wc -l || echo "?")
  say "  ${YELLOW}[DIFFERS]${NC} target differs from repo source (~$diff_lines diff lines)"
  say ""
  say "  ${BOLD}Choose:${NC}"
  say "    ${BLUE}[k]${NC} keep existing (skip — no symlink, repo version unused)"
  say "    ${BLUE}[r]${NC} replace: backup existing, symlink to repo"
  say "    ${BLUE}[m]${NC} merge manually: opens \$EDITOR with diff, then you decide"
  say "    ${BLUE}[d]${NC} show full diff (no action yet)"
  say "    ${BLUE}[s]${NC} skip for this run (no change)"

  if [[ "$DRY_RUN" = 1 ]]; then
    say "  ${DIM}DRY: would prompt user${NC}"
    return 0
  fi

  local choice=""
  while true; do
    read -rp "  > " choice
    case "$choice" in
      k|K|keep)
        say "  ${YELLOW}[KEEP]${NC} $target unchanged. repo source unused."
        return 0
        ;;
      r|R|replace)
        backup_file "$target"
        run "ln -sf \"$src\" \"$target\""
        say "  ${GREEN}[REPLACED]${NC}"
        return 0
        ;;
      m|M|merge)
        local editor="${EDITOR:-vi}"
        local tmp; tmp=$(mktemp)
        diff -u "$target" "$src" > "$tmp" || true
        say "  opening $editor with diff. save+quit to continue..."
        $editor "$tmp"
        rm -f "$tmp"
        say "  after manual edit: rerun merge-dotfiles.sh to finalize, or use [r] if you edited ${target} in place."
        return 0
        ;;
      d|D|diff)
        diff -u "$target" "$src" | sed 's/^/    /' | head -80
        say "  (re-prompting)"
        continue
        ;;
      s|S|skip|"")
        say "  ${DIM}[SKIP]${NC}"
        return 0
        ;;
      *)
        say "  unknown choice: $choice"
        continue
        ;;
    esac
  done
}

say "${BOLD}merge-dotfiles.sh${NC} — interactive dotfiles reconciliation"
say "  ROBOT_ROOT: $ROBOT_ROOT"
[[ "$DRY_RUN" = 1 ]] && say "  ${YELLOW}DRY-RUN mode — no files will be modified${NC}"
say ""

for entry in "${MAPPING[@]}"; do
  IFS='|' read -r tag src target <<<"$entry"
  if [[ -n "$FILTER" && "$FILTER" != "$tag" ]]; then continue; fi
  handle_file "$tag" "$src" "$target"
  say ""
done

say "${GREEN}done.${NC} Run ${BOLD}scripts/doctor.sh --layer=dotfiles${NC} to verify."
