#!/usr/bin/env bash
# install.sh — robot distribution layer orchestrator
#
# Layered, idempotent, resumable installer. See .omc/plans/robot-distribution-plan.md F-1.
#
# Layers: host → dotfiles → cli → claude → vendor → child (child is informational)
# State:  $ROBOT_ROOT/.omc/state/install/<layer>.{done,fail}
# Logs:   $ROBOT_ROOT/.omc/logs/install-<ts>.log
#
# Exit codes:
#   0  success
#   1  layer failure
#   2  pre-flight failure (OS, marker parse, secrets missing, invalid args)
#   3  lock held (concurrent invocation)

set -euo pipefail

# ------------------------------------------------------------------------------
# ROBOT_ROOT resolver (plan lines 85-109)
# ------------------------------------------------------------------------------
resolve_robot_root() {
  if [[ -n "${ROBOT_ROOT:-}" ]]; then
    echo "$ROBOT_ROOT"
    return 0
  fi
  local anchor
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    anchor="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  else
    anchor="$PWD"
  fi
  if git -C "$anchor" rev-parse --show-toplevel &>/dev/null; then
    git -C "$anchor" rev-parse --show-toplevel
    return 0
  fi
  echo "ERROR: ROBOT_ROOT unresolved — set env var or run inside git repo" >&2
  return 2
}

ROBOT_ROOT="$(resolve_robot_root)" || exit 2
export ROBOT_ROOT

STATE_DIR="$ROBOT_ROOT/.omc/state/install"
LOG_DIR="$ROBOT_ROOT/.omc/logs"
mkdir -p "$STATE_DIR" "$LOG_DIR"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/install-$TS.log"

# ------------------------------------------------------------------------------
# Flags (plan F-1 line 175)
# ------------------------------------------------------------------------------
FLAG_DRY_RUN=0
FLAG_STEP=""
FLAG_YES=0
FLAG_ENV_FROM_SHELL=0
FLAG_RESUME=0
FLAG_FORCE_OS=0
FLAG_OVERRIDE=0

usage() {
  cat <<'EOF'
Usage: install.sh [FLAGS]

Flags:
  --dry-run            Print intended actions; write 0 files; exit 0.
  --step=<layer>       Run only one layer: host|dotfiles|cli|claude|vendor|child
  --yes                Skip confirmation prompts.
  --env-from-shell     Read NGC_API_KEY (and peers) from shell env (no interactive prompt).
  --resume             Skip completed layers; start from last failed.
  --force-os           Bypass Ubuntu 22.04 (jammy) check.
  --override           For settings.json merge: allow scalar overwrite (default: preserve).
  -h, --help           Show this help.

Exit codes: 0 ok, 1 layer fail, 2 pre-flight fail, 3 lock held.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run)          FLAG_DRY_RUN=1 ;;
    --step=*)           FLAG_STEP="${arg#--step=}" ;;
    --yes)              FLAG_YES=1 ;;
    --env-from-shell)   FLAG_ENV_FROM_SHELL=1 ;;
    --resume)           FLAG_RESUME=1 ;;
    --force-os)         FLAG_FORCE_OS=1 ;;
    --override)         FLAG_OVERRIDE=1 ;;
    -h|--help)          usage; exit 0 ;;
    *) echo "ERROR: unknown flag: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

case "$FLAG_STEP" in
  ""|host|dotfiles|cli|claude|gemini|vendor|child) ;;
  *) echo "ERROR: invalid --step=$FLAG_STEP (allowed: host|dotfiles|cli|claude|gemini|vendor|child)" >&2; exit 2 ;;
esac

# ------------------------------------------------------------------------------
# Colors + logging (tty-aware)
# ------------------------------------------------------------------------------
if [[ -t 1 ]] && command -v tput &>/dev/null && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
  C_RESET="$(tput sgr0)"
  C_RED="$(tput setaf 1)"
  C_GREEN="$(tput setaf 2)"
  C_YELLOW="$(tput setaf 3)"
  C_BLUE="$(tput setaf 4)"
  C_BOLD="$(tput bold)"
else
  C_RESET="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_BOLD=""
fi

# Route all stdout+stderr through tee to LOG_FILE.
exec > >(tee -a "$LOG_FILE") 2>&1

log_info() { printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
log_ok()   { printf '%s[OK]%s   %s\n' "$C_GREEN" "$C_RESET" "$*"; }
log_skip() { printf '%s[SKIP]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
log_fail() { printf '%s[FAIL]%s %s\n' "$C_RED"   "$C_RESET" "$*" >&2; }
log_warn() { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }

dry() {
  # In dry-run, print "would do" and return 0 without executing $@.
  if [[ $FLAG_DRY_RUN -eq 1 ]]; then
    printf '%s[DRY]%s  would %s\n' "$C_YELLOW" "$C_RESET" "$*"
    return 0
  fi
  return 1
}

# ------------------------------------------------------------------------------
# Concurrency lock (plan Risks row "Concurrent install.sh invocation")
# ------------------------------------------------------------------------------
LOCK_FILE="$STATE_DIR/.lock"
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  echo "${C_RED}[FAIL]${C_RESET} install.sh already running (lock: $LOCK_FILE)" >&2
  exit 3
fi

# ------------------------------------------------------------------------------
# Pre-flight: OS check
# ------------------------------------------------------------------------------
preflight_os() {
  if [[ $FLAG_FORCE_OS -eq 1 ]]; then
    log_warn "OS check bypassed via --force-os"
    return 0
  fi
  local codename=""
  if command -v lsb_release &>/dev/null; then
    codename="$(lsb_release -c 2>/dev/null | awk '{print $2}')"
  fi
  if [[ "$codename" != "jammy" ]]; then
    log_fail "OS check: expected Ubuntu 22.04 (jammy), got '${codename:-unknown}'. Pass --force-os to bypass."
    exit 2
  fi
  log_ok "OS: Ubuntu 22.04 (jammy)"
}

# ------------------------------------------------------------------------------
# sudo keepalive
# ------------------------------------------------------------------------------
SUDO_KEEPALIVE_PID=""
sudo_setup() {
  if [[ $FLAG_DRY_RUN -eq 1 ]]; then
    dry "acquire sudo (sudo -v) and start keepalive"
    return 0
  fi
  if ! sudo -v; then
    log_fail "sudo -v failed; host layer requires sudo"
    exit 2
  fi
  ( while true; do sudo -n true 2>/dev/null || exit 0; sleep 60; done ) &
  SUDO_KEEPALIVE_PID=$!
  log_info "sudo keepalive started (pid=$SUDO_KEEPALIVE_PID)"
}

cleanup() {
  local rc=$?
  if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi
  exit "$rc"
}
trap cleanup EXIT INT TERM

# ------------------------------------------------------------------------------
# State helpers (idempotency)
# Per-layer marker files contain sha256 of layer inputs (R5).
# ------------------------------------------------------------------------------
layer_done_file() { echo "$STATE_DIR/$1.done"; }
layer_fail_file() { echo "$STATE_DIR/$1.fail"; }

# compute_layer_sha <layer> → echoes sha256 of concatenated input file shas
compute_layer_sha() {
  local layer="$1"
  case "$layer" in
    host)
      # host inputs = apt package list signature; stable constant across runs
      printf 'host:v1:apt=jq,xclip,xsel,libfuse2,tmux;nvidia-ctk;docker-ce\n' | sha256sum | awk '{print $1}'
      ;;
    dotfiles)
      {
        for f in "$ROBOT_ROOT/dotfiles/wezterm.lua" \
                 "$ROBOT_ROOT/dotfiles/tmux.conf" \
                 "$ROBOT_ROOT/dotfiles/xprofile" \
                 "$ROBOT_ROOT/dotfiles/wezterm-KEYBINDINGS.md"; do
          [[ -f "$f" ]] && sha256sum "$f" || echo "missing $f"
        done
      } | sha256sum | awk '{print $1}'
      ;;
    cli)
      printf 'cli:v1:node>=20;claude-code;omc-plugin;omc-npm\n' | sha256sum | awk '{print $1}'
      ;;
    claude)
      {
        sha256sum "$ROBOT_ROOT/claude/CLAUDE-marker.md" 2>/dev/null || echo "missing marker"
        sha256sum "$ROBOT_ROOT/claude/settings-seed.json" 2>/dev/null || echo "missing seed"
        for c in "$ROBOT_ROOT"/claude/commands/*.md; do
          [[ -f "$c" ]] && sha256sum "$c"
        done
      } | sha256sum | awk '{print $1}'
      ;;
    gemini)
      {
        sha256sum "$ROBOT_ROOT/gemini/settings-seed.json" 2>/dev/null || echo "missing seed"
        printf 'omg-extension:v0.8.1\n'
      } | sha256sum | awk '{print $1}'
      ;;
    vendor)
      if [[ -f "$ROBOT_ROOT/.gitmodules" ]]; then
        sha256sum "$ROBOT_ROOT/.gitmodules" | awk '{print $1}'
      else
        printf 'vendor:no-gitmodules\n' | sha256sum | awk '{print $1}'
      fi
      ;;
    child)
      printf 'child:info-only:v1\n' | sha256sum | awk '{print $1}'
      ;;
    *) echo "unknown" ;;
  esac
}

layer_is_done() {
  local layer="$1"
  local marker; marker="$(layer_done_file "$layer")"
  [[ -f "$marker" ]] || return 1
  local want have
  want="$(compute_layer_sha "$layer")"
  have="$(cat "$marker" 2>/dev/null | awk 'NR==1{print $1}')"
  [[ "$want" == "$have" ]]
}

mark_done() {
  local layer="$1"
  local sha; sha="$(compute_layer_sha "$layer")"
  printf '%s  %s\n' "$sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$(layer_done_file "$layer")"
  rm -f "$(layer_fail_file "$layer")"
}

mark_fail() {
  local layer="$1" reason="$2"
  {
    printf 'layer: %s\n' "$layer"
    printf 'ts: %s\n'   "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'reason: %s\n' "$reason"
    printf 'log: %s\n' "$LOG_FILE"
  } > "$(layer_fail_file "$layer")"
}

# ------------------------------------------------------------------------------
# Layer list + ordering
# ------------------------------------------------------------------------------
LAYERS=(host dotfiles cli claude gemini vendor child)

# Determine resume start layer from most recent .fail (in LAYERS order).
resume_start_layer() {
  for layer in "${LAYERS[@]}"; do
    if [[ -f "$(layer_fail_file "$layer")" ]]; then
      echo "$layer"
      return 0
    fi
  done
  # No .fail: start at first not-done layer
  for layer in "${LAYERS[@]}"; do
    if ! layer_is_done "$layer"; then
      echo "$layer"
      return 0
    fi
  done
  echo ""  # all done
}

# ------------------------------------------------------------------------------
# Confirmation prompt
# ------------------------------------------------------------------------------
confirm() {
  local msg="$1"
  if [[ $FLAG_YES -eq 1 || $FLAG_DRY_RUN -eq 1 ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    log_info "non-tty + no --yes → assuming yes for: $msg"
    return 0
  fi
  local reply
  read -r -p "$msg [y/N] " reply
  [[ "$reply" =~ ^[Yy] ]]
}

# ------------------------------------------------------------------------------
# Layer: host  (apt, NVIDIA Container Toolkit, Docker)
# ------------------------------------------------------------------------------
run_host() {
  log_info "== host layer =="
  sudo_setup

  local apt_pkgs=(jq xclip xsel libfuse2 tmux curl ca-certificates gnupg lsb-release)

  if dry "apt-get update && apt-get install -y ${apt_pkgs[*]}"; then
    :
  else
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${apt_pkgs[@]}"
    log_ok "apt packages installed"
  fi

  # Docker (if missing)
  if ! command -v docker &>/dev/null; then
    if dry "install Docker CE via get.docker.com convenience script"; then
      :
    else
      curl -fsSL https://get.docker.com | sudo sh
      sudo usermod -aG docker "$USER" || true
      log_ok "Docker installed (re-login or 'newgrp docker' for group effect)"
    fi
  else
    log_skip "docker already present ($(docker --version 2>/dev/null || echo unknown))"
  fi

  # NVIDIA Container Toolkit
  if ! command -v nvidia-ctk &>/dev/null; then
    if dry "install NVIDIA Container Toolkit (nvidia-container-toolkit apt repo)"; then
      :
    else
      local kr=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
      curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | sudo gpg --dearmor --yes -o "$kr"
      curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        | sed "s#deb https://#deb [signed-by=$kr] https://#g" \
        | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
      sudo apt-get update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-container-toolkit
      sudo nvidia-ctk runtime configure --runtime=docker || true
      sudo systemctl restart docker || true
      log_ok "nvidia-container-toolkit installed + docker runtime configured"
    fi
  else
    log_skip "nvidia-ctk already present"
  fi
}

# ------------------------------------------------------------------------------
# Layer: dotfiles  (symlink with .pre-robot.<ts>.bak fallback)
# ------------------------------------------------------------------------------
# symlink_dotfile <src_in_repo> <target_in_home>
symlink_dotfile() {
  local src="$1" target="$2"
  local src_abs="$ROBOT_ROOT/dotfiles/$src"

  if [[ ! -f "$src_abs" && ! -L "$src_abs" ]]; then
    log_warn "source missing: $src_abs (skip)"
    return 0
  fi

  mkdir -p "$(dirname "$target")"

  # Already correctly symlinked → SKIP
  if [[ -L "$target" ]]; then
    local cur; cur="$(readlink "$target")"
    if [[ "$cur" == "$src_abs" ]]; then
      log_skip "$target → $src_abs (already linked)"
      return 0
    fi
  fi

  # Existing regular file or wrong symlink → backup + replace
  if [[ -e "$target" || -L "$target" ]]; then
    local bak="${target}.pre-robot.${TS}.bak"
    if dry "mv '$target' '$bak'"; then
      :
    else
      mv "$target" "$bak"
      log_info "backed up $target → $bak"
    fi
  fi

  if dry "ln -s '$src_abs' '$target'"; then
    :
  else
    ln -s "$src_abs" "$target"
    log_ok "$target → $src_abs"
  fi
}

run_dotfiles() {
  log_info "== dotfiles layer =="
  symlink_dotfile wezterm.lua             "$HOME/.config/wezterm/wezterm.lua"
  symlink_dotfile wezterm-KEYBINDINGS.md  "$HOME/.config/wezterm/KEYBINDINGS.md"
  symlink_dotfile tmux.conf               "$HOME/.tmux.conf"
  symlink_dotfile xprofile                "$HOME/.xprofile"
}

# ------------------------------------------------------------------------------
# Layer: cli  (Node.js ≥20, Claude Code CLI, OMC plugin, omc npm)
# ------------------------------------------------------------------------------
check_node_version() {
  command -v node &>/dev/null || return 1
  local v; v="$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1)"
  [[ "$v" =~ ^[0-9]+$ ]] || return 1
  (( v >= 20 ))
}

run_cli() {
  log_info "== cli layer =="

  if check_node_version; then
    log_skip "node $(node -v) already ≥20"
  else
    if dry "install Node.js 20.x via NodeSource"; then
      :
    else
      sudo_setup
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
      log_ok "Node.js $(node -v 2>/dev/null || echo '?') installed"
    fi
  fi

  if command -v claude &>/dev/null; then
    log_skip "claude CLI present ($(claude --version 2>/dev/null | head -1 || echo unknown))"
  else
    if dry "npm install -g @anthropic-ai/claude-code"; then
      :
    else
      npm install -g @anthropic-ai/claude-code
      log_ok "claude CLI installed"
    fi
  fi

  # OMC plugin (best-effort; omc-setup is the canonical path)
  if command -v claude &>/dev/null; then
    if dry "claude plugin install oh-my-claudecode (if not present)"; then
      :
    else
      claude plugin install oh-my-claudecode 2>/dev/null \
        && log_ok "OMC plugin installed" \
        || log_warn "OMC plugin install: not available via claude plugin — run /oh-my-claudecode:omc-setup manually"
    fi
  fi

  if command -v omc &>/dev/null; then
    log_skip "omc npm present"
  else
    if dry "npm install -g omc"; then
      :
    else
      npm install -g omc 2>/dev/null \
        && log_ok "omc npm installed" \
        || log_warn "omc npm install failed (non-critical)"
    fi
  fi

  # rtk — token-compressing CLI proxy for Claude Code (60-90% bash output reduction).
  # Installs to ~/.local/bin (user scope). Then wires the Claude Code hook globally.
  local rtk_bin="$HOME/.local/bin/rtk"
  if [[ -x "$rtk_bin" ]] || command -v rtk &>/dev/null; then
    log_skip "rtk present ($("${rtk_bin:-rtk}" --version 2>/dev/null || echo unknown))"
  else
    if dry "install rtk via curl | sh (user-scope ~/.local/bin)"; then
      :
    else
      curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh \
        && log_ok "rtk installed" \
        || log_warn "rtk install failed (non-critical — retry with brew/cargo)"
    fi
  fi

  # Wire rtk into ~/.claude (idempotent; rtk init --show indicates current state)
  if [[ -x "$rtk_bin" ]] || command -v rtk &>/dev/null; then
    local rtk_exe="${rtk_bin}"
    [[ -x "$rtk_exe" ]] || rtk_exe="$(command -v rtk)"
    if "$rtk_exe" init --show 2>/dev/null | grep -q '^\[ok\] Hook: rtk hook claude'; then
      log_skip "rtk hook already registered globally"
    else
      if dry "rtk init -g --auto-patch (global hook + RTK.md + @RTK.md + settings.json patch)"; then
        :
      else
        "$rtk_exe" init -g --auto-patch \
          && log_ok "rtk hook registered globally" \
          || log_warn "rtk init failed (non-critical — run 'rtk init -g --auto-patch' manually)"
      fi
    fi
  fi
}

# ------------------------------------------------------------------------------
# Layer: claude  (marker inject + settings merge + commands symlink)
# ------------------------------------------------------------------------------

# ---- E-0: marker injection state machine ------------------------------------
# Parses ~/.claude/CLAUDE.md, locates OMC and OMC:ROBOT tokens, then
# updates-or-inserts the ROBOT block. Reject conditions backup+exit 2.
inject_marker() {
  local claude_md="$HOME/.claude/CLAUDE.md"
  local marker_src="$ROBOT_ROOT/claude/CLAUDE-marker.md"

  if [[ ! -f "$marker_src" ]]; then
    log_fail "marker source missing: $marker_src"
    return 1
  fi

  mkdir -p "$HOME/.claude"

  if [[ ! -f "$claude_md" ]]; then
    if dry "create $claude_md from marker source"; then
      return 0
    fi
    cp "$marker_src" "$claude_md"
    log_ok "created $claude_md (marker-only)"
    return 0
  fi

  # Scan tokens
  local line_no=0
  local omc_start=0 omc_end=0 robot_start=0 robot_end=0
  local dup_omc_start=0 dup_omc_end=0 dup_robot_start=0 dup_robot_end=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    case "$line" in
      *'<!-- OMC:START -->'*)
        if (( omc_start > 0 )); then dup_omc_start=1; else omc_start=$line_no; fi ;;
      *'<!-- OMC:END -->'*)
        if (( omc_end > 0 )); then dup_omc_end=1; else omc_end=$line_no; fi ;;
      *'<!-- OMC:ROBOT:START -->'*)
        if (( robot_start > 0 )); then dup_robot_start=1; else robot_start=$line_no; fi ;;
      *'<!-- OMC:ROBOT:END -->'*)
        if (( robot_end > 0 )); then dup_robot_end=1; else robot_end=$line_no; fi ;;
    esac
  done < "$claude_md"

  # Reject conditions
  local reject_reason=""
  if (( dup_omc_start || dup_omc_end || dup_robot_start || dup_robot_end )); then
    reject_reason="duplicate OMC/ROBOT token detected"
  elif (( omc_start > 0 && omc_end == 0 )) || (( omc_end > 0 && omc_start == 0 )); then
    reject_reason="unmatched OMC START/END"
  elif (( robot_start > 0 && robot_end == 0 )) || (( robot_end > 0 && robot_start == 0 )); then
    reject_reason="unmatched OMC:ROBOT START/END"
  elif (( omc_start > 0 && omc_end > 0 && omc_end < omc_start )); then
    reject_reason="OMC:END before OMC:START"
  elif (( robot_start > 0 && robot_end > 0 && robot_end < robot_start )); then
    reject_reason="OMC:ROBOT:END before OMC:ROBOT:START"
  elif (( omc_start > 0 && omc_end > 0 && robot_start > 0 )) \
       && (( robot_start > omc_start && robot_start < omc_end )); then
    reject_reason="OMC:ROBOT block nested inside OMC block (AC-7 violation)"
  fi

  if [[ -n "$reject_reason" ]]; then
    local bak="${claude_md}.pre-robot.${TS}.bak"
    if dry "backup $claude_md → $bak and exit 2 (reject: $reject_reason)"; then
      return 0
    fi
    cp "$claude_md" "$bak"
    log_fail "marker parse rejected: $reject_reason"
    log_fail "backup: $bak"
    log_fail "see docs/INSTALL.md §manual-recovery"
    exit 2
  fi

  # Update path: ROBOT block exists → replace lines [robot_start..robot_end]
  if (( robot_start > 0 && robot_end > 0 )); then
    if dry "replace lines $robot_start-$robot_end of $claude_md with $marker_src"; then
      return 0
    fi
    local tmp="${claude_md}.tmp.${TS}"
    {
      awk -v s="$robot_start" -v e="$robot_end" 'NR<s { print } NR==s { exit }' "$claude_md"
      cat "$marker_src"
      awk -v e="$robot_end" 'NR>e { print }' "$claude_md"
    } > "$tmp"
    mv "$tmp" "$claude_md"
    log_ok "replaced OMC:ROBOT block (lines $robot_start-$robot_end)"
    return 0
  fi

  # Insert path: ROBOT block missing → append after OMC:END (or EOF if no OMC)
  if (( omc_end > 0 )); then
    if dry "insert marker after line $omc_end in $claude_md"; then
      return 0
    fi
    local tmp="${claude_md}.tmp.${TS}"
    {
      awk -v e="$omc_end" 'NR<=e { print }' "$claude_md"
      echo ""
      cat "$marker_src"
      awk -v e="$omc_end" 'NR>e { print }' "$claude_md"
    } > "$tmp"
    mv "$tmp" "$claude_md"
    log_ok "inserted OMC:ROBOT block after OMC:END (line $omc_end)"
  else
    if dry "append marker to EOF of $claude_md"; then
      return 0
    fi
    {
      echo ""
      cat "$marker_src"
    } >> "$claude_md"
    log_ok "appended OMC:ROBOT block to EOF"
  fi
}

# ---- E-2: settings-seed merge with jq ---------------------------------------
merge_settings() {
  local user_settings="$HOME/.claude/settings.json"
  local seed="$ROBOT_ROOT/claude/settings-seed.json"
  local merge_log="$LOG_DIR/settings-merge-$TS.log"

  if [[ ! -f "$seed" ]]; then
    log_fail "settings seed missing: $seed"
    return 1
  fi

  if ! command -v jq &>/dev/null; then
    log_fail "jq required for settings merge (install host layer first)"
    return 1
  fi

  mkdir -p "$HOME/.claude"

  # Strip _description from seed
  local seed_clean
  seed_clean="$(jq 'del(._description)' "$seed")" || {
    log_fail "seed is invalid JSON: $seed"
    return 1
  }

  if [[ ! -f "$user_settings" ]]; then
    if dry "write $user_settings (seed-only, ${#seed_clean} bytes)"; then
      return 0
    fi
    printf '%s\n' "$seed_clean" > "$user_settings"
    log_ok "created $user_settings from seed"
    echo "created fresh settings.json from seed at $TS" > "$merge_log"
    return 0
  fi

  # Validate user settings is JSON
  if ! jq empty "$user_settings" 2>/dev/null; then
    local bak="${user_settings}.pre-robot.${TS}.bak"
    log_fail "user settings.json is invalid JSON"
    if dry "backup to $bak and abort merge"; then
      return 1
    fi
    cp "$user_settings" "$bak"
    log_fail "backup: $bak — restore manually or fix JSON and re-run"
    return 1
  fi

  if dry "merge $seed into $user_settings (override=$FLAG_OVERRIDE)"; then
    return 0
  fi

  # Merge program: recursive walk; arrays additive with canonical dedup;
  # scalars preserve unless override=1; type-mismatch preserves user + warn.
  local tmp="${user_settings}.tmp.${TS}"
  local bak_pre="${user_settings}.pre-robot.${TS}.bak"
  cp "$user_settings" "$bak_pre"

  local jq_program='
    # merge seed into user. user wins for scalars unless $override.
    # arrays: concat + canonical JSON dedup (objects sorted keys).
    def merge($user; $seed; $override):
      if ($user | type) == "object" and ($seed | type) == "object" then
        reduce ($seed | keys_unsorted[]) as $k (
          $user;
          .[$k] = (
            if (.[$k] == null) then $seed[$k]
            elif (.[$k] | type) == ($seed[$k] | type) then
              if (.[$k] | type) == "object" then
                merge(.[$k]; $seed[$k]; $override)
              elif (.[$k] | type) == "array" then
                # additive dedup by canonical form
                ( (.[$k] + $seed[$k])
                  | map({k: (. | tojson), v: .})
                  | unique_by(.k)
                  | map(.v) )
              else
                # scalar
                if $override then $seed[$k] else .[$k] end
              end
            else
              # type mismatch → preserve user (warn printed by caller)
              .[$k]
            end
          )
        )
      else
        $user
      end;
    merge($user; $seed; $override)
  '

  if jq -n \
        --argjson user   "$(jq --sort-keys . "$user_settings")" \
        --argjson seed   "$(printf '%s' "$seed_clean" | jq --sort-keys .)" \
        --argjson override "$([[ $FLAG_OVERRIDE -eq 1 ]] && echo true || echo false)" \
        "$jq_program" > "$tmp"; then
    :
  else
    log_fail "jq merge failed; restoring from backup"
    cp "$bak_pre" "$user_settings"
    rm -f "$tmp"
    return 1
  fi

  # Validate output
  if ! jq empty "$tmp" 2>/dev/null; then
    log_fail "merged output is invalid JSON; restoring from backup"
    cp "$bak_pre" "$user_settings"
    rm -f "$tmp"
    return 1
  fi

  # Type-mismatch detection → warn log
  local mismatches
  mismatches="$(jq -n \
    --argjson u "$(jq --sort-keys . "$user_settings")" \
    --argjson s "$(printf '%s' "$seed_clean" | jq --sort-keys .)" '
    def walk($u; $s; $path):
      if ($u | type) == "object" and ($s | type) == "object" then
        [ ($s | keys_unsorted[]) as $k
          | if ($u[$k] != null) and (($u[$k] | type) != ($s[$k] | type))
            then "\($path + [$k] | join("."))  user=\($u[$k] | type)  seed=\($s[$k] | type)"
            else empty end
        ] + [ ($s | keys_unsorted[]) as $k
              | if ($u[$k] != null) and (($u[$k] | type) == "object") and (($s[$k] | type) == "object")
                then walk($u[$k]; $s[$k]; $path + [$k])[]
                else empty end ]
      else [] end;
    walk($u; $s; []) | .[]' 2>/dev/null || true)"

  if [[ -n "$mismatches" ]]; then
    log_warn "type-mismatch (user preserved):"
    printf '%s\n' "$mismatches" | while read -r ln; do log_warn "  $ln"; done
  fi

  # Atomic replace
  mv "$tmp" "$user_settings"

  # Diff log
  {
    printf '# settings-merge %s\n' "$TS"
    printf '# override=%s\n' "$FLAG_OVERRIDE"
    printf '# pre-merge backup: %s\n\n' "$bak_pre"
    diff -u "$bak_pre" "$user_settings" || true
    if [[ -n "$mismatches" ]]; then
      printf '\n## Type mismatches (user preserved)\n%s\n' "$mismatches"
    fi
  } > "$merge_log"

  log_ok "settings merged → $user_settings (log: $merge_log)"
}

# ---- commands symlink --------------------------------------------------------
link_commands() {
  local dst_dir="$HOME/.claude/commands"
  mkdir -p "$dst_dir"
  local f
  for f in "$ROBOT_ROOT"/claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    local base; base="$(basename "$f")"
    local target="$dst_dir/$base"
    if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$f" ]]; then
      log_skip "$target → $f (already linked)"
      continue
    fi
    if [[ -e "$target" || -L "$target" ]]; then
      local bak="${target}.pre-robot.${TS}.bak"
      if dry "mv '$target' '$bak'"; then
        :
      else
        mv "$target" "$bak"
      fi
    fi
    if dry "ln -s '$f' '$target'"; then
      :
    else
      ln -s "$f" "$target"
      log_ok "linked $target → $f"
    fi
  done
}

# ---- secrets (NGC_API_KEY → .env.local) -------------------------------------
handle_secrets() {
  local env_local="$ROBOT_ROOT/.env.local"

  if [[ -f "$env_local" ]] && grep -q '^NGC_API_KEY=' "$env_local"; then
    log_skip ".env.local already contains NGC_API_KEY"
    return 0
  fi

  local key_value=""
  if [[ $FLAG_ENV_FROM_SHELL -eq 1 ]]; then
    if [[ -n "${NGC_API_KEY:-}" ]]; then
      key_value="$NGC_API_KEY"
    else
      log_fail "--env-from-shell requested but NGC_API_KEY is not exported in shell"
      return 1
    fi
  elif [[ -t 0 && -t 1 ]]; then
    printf 'NGC_API_KEY (input hidden): '
    read -rs key_value
    echo
  else
    log_fail ".env.local missing and no NGC_API_KEY provided. Re-run interactively or with --env-from-shell (NGC_API_KEY=… install.sh --env-from-shell)"
    return 1
  fi

  if [[ -z "$key_value" ]]; then
    log_fail "empty NGC_API_KEY — refusing to write .env.local"
    return 1
  fi

  if dry "write NGC_API_KEY to $env_local (mode 600)"; then
    return 0
  fi

  umask 077
  {
    printf '# robot distribution — .env.local (gitignored). Written by install.sh at %s.\n' "$TS"
    printf 'NGC_API_KEY=%s\n' "$key_value"
  } > "$env_local"
  chmod 600 "$env_local"
  log_ok "wrote $env_local (mode 600)"
}

run_claude() {
  log_info "== claude layer =="
  inject_marker
  merge_settings
  link_commands
  handle_secrets

  # Register github-mcp-server (idempotent via claude mcp add)
  if command -v claude &>/dev/null; then
    if dry "claude mcp add github-mcp-server -s user -- npx -y @modelcontextprotocol/server-github"; then
      :
    else
      if claude mcp list 2>/dev/null | grep -q "github-mcp-server"; then
        log_skip "github-mcp-server already registered in user scope"
      else
        claude mcp add github-mcp-server -s user -- npx -y @modelcontextprotocol/server-github \
          && log_ok "github-mcp-server registered in user scope" \
          || log_warn "github-mcp-server registration failed"
      fi
    fi
  fi
}

# ------------------------------------------------------------------------------
# Layer: gemini  (CLI check + OMG extension + settings seed + trustedFolders)
# ------------------------------------------------------------------------------
run_gemini() {
  log_info "== gemini layer =="

  # Step 1: Gemini CLI presence
  if ! command -v gemini &>/dev/null; then
    log_warn "gemini CLI not found — install manually: npm install -g @google/gemini-cli"
    log_warn "skip: gemini layer requires the CLI; re-run after install"
    return 0
  fi
  local gver; gver="$(gemini --version 2>/dev/null | head -1)"
  log_ok "gemini CLI present (version=$gver)"

  # Step 2: OMG extension at pinned version
  local omg_dir="$HOME/.gemini/extensions/oh-my-gemini-cli"
  local omg_manifest="$omg_dir/gemini-extension.json"
  local target_version="0.8.1"
  local omg_url="https://github.com/Joonghyun-Lee-Frieren/oh-my-gemini-cli"

  if [[ -f "$omg_manifest" ]]; then
    local cur_ver; cur_ver="$(jq -r .version "$omg_manifest" 2>/dev/null || echo unknown)"
    if [[ "$cur_ver" == "$target_version" ]]; then
      log_skip "oh-my-gemini-cli v$cur_ver already installed (target v$target_version)"
    else
      log_warn "oh-my-gemini-cli v$cur_ver installed; target v$target_version (upgrade manually: gemini extensions update oh-my-gemini-cli)"
    fi
  else
    if dry "gemini extensions install $omg_url"; then
      :
    elif confirm "Install oh-my-gemini-cli extension now?"; then
      gemini extensions install "$omg_url" \
        && log_ok "oh-my-gemini-cli installed (version $(jq -r .version "$omg_manifest" 2>/dev/null || echo unknown))" \
        || log_warn "gemini extensions install failed — install manually"
    else
      log_skip "extension install declined"
    fi
  fi

  # Step 3: settings-seed merge (auth-preserving)
  local gem_settings="$HOME/.gemini/settings.json"
  local gem_seed="$ROBOT_ROOT/gemini/settings-seed.json"

  if [[ ! -f "$gem_seed" ]]; then
    log_warn "gemini seed missing: $gem_seed"
  elif ! command -v jq &>/dev/null; then
    log_fail "jq required for settings merge (run host layer first)"
  else
    mkdir -p "$HOME/.gemini"
    local seed_clean; seed_clean="$(jq 'del(._description)' "$gem_seed")"
    if [[ ! -f "$gem_settings" ]]; then
      if dry "write $gem_settings (seed-only)"; then
        :
      else
        printf '%s\n' "$seed_clean" > "$gem_settings"
        log_ok "created $gem_settings from seed"
      fi
    else
      # Never overwrite user's security.auth. Deep-merge seed into existing.
      if dry "deep-merge seed into $gem_settings (preserve security.auth)"; then
        :
      else
        local bak="${gem_settings}.pre-robot.${TS}.bak"
        cp "$gem_settings" "$bak"
        local merged; merged="$(jq -s '.[0] * .[1]' "$gem_settings" "$gem_seed" | jq 'del(._description)')"
        if [[ -n "$merged" ]] && echo "$merged" | jq empty 2>/dev/null; then
          printf '%s\n' "$merged" > "$gem_settings"
          log_ok "merged seed into $gem_settings (backup: $bak)"
        else
          log_warn "merge produced invalid JSON — kept original, backup $bak preserved"
        fi
      fi
    fi
  fi

  # Step 4: trustedFolders registration
  local trust="$HOME/.gemini/trustedFolders.json"
  if command -v jq &>/dev/null; then
    mkdir -p "$HOME/.gemini"
    local entry="$ROBOT_ROOT"
    if [[ -f "$trust" ]] && jq -e --arg k "$entry" '.[$k]' "$trust" &>/dev/null; then
      log_skip "trustedFolders already has $entry"
    else
      if dry "add $entry to $trust as TRUST_FOLDER"; then
        :
      else
        local base="{}"
        [[ -f "$trust" ]] && base="$(cat "$trust")"
        printf '%s' "$base" | jq --arg k "$entry" '. + {($k): "TRUST_FOLDER"}' > "$trust"
        log_ok "registered $entry in $trust"
      fi
    fi
  fi
}

# ------------------------------------------------------------------------------
# Layer: vendor  (submodule verification — info only)
# ------------------------------------------------------------------------------
run_vendor() {
  log_info "== vendor layer =="

  local vdir="$ROBOT_ROOT/vendor/isaac-sim-mcp"
  local edir="$ROBOT_ROOT/external/robotics-agent-skills"
  local gitmodules="$ROBOT_ROOT/.gitmodules"

  if [[ ! -f "$gitmodules" ]]; then
    log_warn ".gitmodules missing — nothing to initialize"
    return 0
  fi

  # Initialize any missing submodule working trees.
  local need_init=0
  if [[ ! -d "$vdir" ]] || [[ -z "$(ls -A "$vdir" 2>/dev/null)" ]]; then need_init=1; fi
  if [[ ! -d "$edir" ]] || [[ -z "$(ls -A "$edir" 2>/dev/null)" ]]; then need_init=1; fi

  if (( need_init )); then
    log_warn "submodules not populated; run: git submodule update --init --recursive"
    if dry "git submodule update --init --recursive"; then
      return 0
    fi
    if confirm "Run 'git submodule update --init --recursive' now?"; then
      git -C "$ROBOT_ROOT" submodule update --init --recursive
      log_ok "submodules initialized"
    else
      log_skip "submodule init declined"
      return 0
    fi
  fi

  # Report HEAD for each declared submodule.
  for sm in "$vdir" "$edir"; do
    local rel="${sm#$ROBOT_ROOT/}"
    if [[ -d "$sm/.git" || -f "$sm/.git" ]]; then
      local sha; sha="$(git -C "$sm" rev-parse --short HEAD 2>/dev/null || echo unknown)"
      log_ok "$rel present (HEAD=$sha)"
    elif [[ -d "$sm" ]]; then
      log_warn "$rel exists but is not a git checkout"
    fi
  done

  # Compat symlink ~/robot/isaac-sim-mcp → vendor/isaac-sim-mcp
  local compat="$ROBOT_ROOT/isaac-sim-mcp"
  if [[ -L "$compat" ]] && [[ "$(readlink "$compat")" == "vendor/isaac-sim-mcp" || "$(readlink "$compat")" == "$vdir" ]]; then
    log_skip "compat symlink ok: $compat"
  elif [[ ! -e "$compat" ]]; then
    if dry "ln -s vendor/isaac-sim-mcp '$compat'"; then
      :
    else
      ln -s vendor/isaac-sim-mcp "$compat"
      log_ok "created compat symlink $compat → vendor/isaac-sim-mcp"
    fi
  else
    log_warn "compat path $compat exists and is not the expected symlink — left untouched"
  fi
}

# ------------------------------------------------------------------------------
# Layer: child  (informational only — points at bootstrap-child.sh)
# ------------------------------------------------------------------------------
run_child() {
  log_info "== child layer (informational) =="
  log_info "To create a child project:"
  log_info "  $ROBOT_ROOT/scripts/bootstrap-child.sh <name> --profile=isaac+ros2"
  log_info "Templates: $ROBOT_ROOT/templates/"
}

# ------------------------------------------------------------------------------
# Layer dispatcher
# ------------------------------------------------------------------------------
run_layer() {
  local layer="$1"

  if layer_is_done "$layer" && [[ $FLAG_DRY_RUN -eq 0 ]]; then
    log_skip "$layer (already done — sha match)"
    return 0
  fi

  # Trap failure to write .fail marker then re-raise.
  set +e
  (
    set -e
    case "$layer" in
      host)     run_host ;;
      dotfiles) run_dotfiles ;;
      cli)      run_cli ;;
      claude)   run_claude ;;
      gemini)   run_gemini ;;
      vendor)   run_vendor ;;
      child)    run_child ;;
      *) log_fail "unknown layer: $layer"; exit 1 ;;
    esac
  )
  local rc=$?
  set -e

  if [[ $rc -eq 0 ]]; then
    if [[ $FLAG_DRY_RUN -eq 1 ]]; then
      log_info "dry-run: not writing $layer.done"
    else
      mark_done "$layer"
      log_ok "layer '$layer' complete (marker written)"
    fi
  else
    if [[ $FLAG_DRY_RUN -eq 0 ]]; then
      mark_fail "$layer" "exit=$rc"
    fi
    log_fail "layer '$layer' failed (rc=$rc)"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
main() {
  log_info "robot install — root=$ROBOT_ROOT  ts=$TS  log=$LOG_FILE"
  log_info "flags: dry-run=$FLAG_DRY_RUN step=${FLAG_STEP:-<all>} yes=$FLAG_YES env-from-shell=$FLAG_ENV_FROM_SHELL resume=$FLAG_RESUME force-os=$FLAG_FORCE_OS override=$FLAG_OVERRIDE"

  preflight_os

  # Determine layer list
  local -a targets
  if [[ -n "$FLAG_STEP" ]]; then
    targets=("$FLAG_STEP")
  elif [[ $FLAG_RESUME -eq 1 ]]; then
    local start; start="$(resume_start_layer)"
    if [[ -z "$start" ]]; then
      log_ok "All layers complete. Nothing to do."
      exit 0
    fi
    log_info "resume: starting from layer '$start'"
    local started=0 l
    targets=()
    for l in "${LAYERS[@]}"; do
      if [[ "$l" == "$start" ]]; then started=1; fi
      if [[ $started -eq 1 ]]; then targets+=("$l"); fi
    done
  else
    targets=("${LAYERS[@]}")
  fi

  local l
  for l in "${targets[@]}"; do
    if ! run_layer "$l"; then
      log_fail "aborting after layer '$l' failure — re-run with --resume after fixing"
      exit 1
    fi
  done

  if [[ $FLAG_DRY_RUN -eq 1 ]]; then
    log_ok "dry-run complete (0 files written)"
  else
    log_ok "install complete"
  fi
}

main "$@"
