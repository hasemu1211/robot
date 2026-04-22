#!/usr/bin/env bash
# doctor.sh — robot distribution health checker
# Usage:
#   doctor.sh                  human-readable colored output, exit 0=all-green/warn, 1=any-fail
#   doctor.sh --json           JSON schema v1 to stdout, exit 0 always
#   doctor.sh --layer=<name>   run only one layer's checks (human output)
#   doctor.sh --layer=<name> --json  run one layer, JSON output
#
# Layers: host dotfiles cli claude gemini mcp vendor secrets templates datafactory
set -euo pipefail

# ---------------------------------------------------------------------------
# ROBOT_ROOT resolver (shared contract with install.sh / bootstrap-child.sh)
# ---------------------------------------------------------------------------
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
  echo "ERROR: ROBOT_ROOT undetermined — set env var or run inside git repo" >&2
  return 2
}

ROBOT_ROOT="$(resolve_robot_root)"
readonly ROBOT_ROOT

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
JSON_MODE=false
ONLY_LAYER=""

for arg in "$@"; do
  case "$arg" in
    --json)           JSON_MODE=true ;;
    --layer=*)        ONLY_LAYER="${arg#--layer=}" ;;
    -h|--help)
      echo "Usage: $0 [--json] [--layer=<name>]"
      echo "Layers: host dotfiles cli claude gemini mcp vendor secrets templates datafactory"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Result storage
# ---------------------------------------------------------------------------
# Associative arrays: RESULTS[layer.check] = "status|message"
# DETAIL[layer.check] = optional JSON fragment for detail field
declare -A RESULTS
declare -A DETAIL

# Counters
COUNT_GREEN=0
COUNT_WARN=0
COUNT_FAIL=0

# ---------------------------------------------------------------------------
# Color helpers (no-op in JSON mode)
# ---------------------------------------------------------------------------
if [[ "$JSON_MODE" == "false" ]] && [[ -t 1 ]]; then
  C_RESET='\033[0m'
  C_GREEN='\033[0;32m'
  C_YELLOW='\033[0;33m'
  C_RED='\033[0;31m'
  C_BOLD='\033[1m'
else
  C_RESET='' C_GREEN='' C_YELLOW='' C_RED='' C_BOLD=''
fi

icon_green() { echo -e "${C_GREEN}[OK]  ${C_RESET}"; }
icon_warn()  { echo -e "${C_YELLOW}[WARN]${C_RESET}"; }
icon_fail()  { echo -e "${C_RED}[FAIL]${C_RESET}"; }

# ---------------------------------------------------------------------------
# record_check <layer> <check> <status: green|warn|fail> <message> [detail_json]
# ---------------------------------------------------------------------------
record_check() {
  local layer="$1" check="$2" status="$3" message="$4" detail="${5:-}"
  RESULTS["${layer}.${check}"]="${status}|${message}"
  if [[ -n "$detail" ]]; then
    DETAIL["${layer}.${check}"]="$detail"
  fi
  case "$status" in
    green) COUNT_GREEN=$((COUNT_GREEN + 1)) ;;
    warn)  COUNT_WARN=$((COUNT_WARN + 1)) ;;
    fail)  COUNT_FAIL=$((COUNT_FAIL + 1)) ;;
  esac
}

# ---------------------------------------------------------------------------
# Layer: host
# ---------------------------------------------------------------------------
check_host() {
  # host.docker
  if docker --version &>/dev/null; then
    local ver
    ver="$(docker --version 2>/dev/null | head -1)"
    record_check host docker green "$ver"
  else
    record_check host docker fail "docker not found or not runnable"
  fi

  # host.nvidia
  local nvidia_out nvidia_status nvidia_msg nvidia_detail
  if nvidia-smi --query-gpu=compute_cap,memory.total --format=csv,noheader,nounits &>/dev/null; then
    nvidia_out="$(nvidia-smi --query-gpu=compute_cap,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)"
    local sm_raw vram_raw
    sm_raw="$(echo "$nvidia_out" | awk -F',' '{print $1}' | tr -d ' ')"
    vram_raw="$(echo "$nvidia_out" | awk -F',' '{print $2}' | tr -d ' ')"
    # sm_raw e.g. "8.6" or "12.0" → strip dot → numeric compare as integer (860, 1200)
    local sm_int vram_gb
    sm_int="$(echo "$sm_raw" | awk -F'.' '{printf "%d%02d", $1, ($2+0)}')"
    # vram_raw is MiB; convert to GB (integer)
    vram_gb="$(echo "$vram_raw" | awk '{printf "%d", $1/1024}')"
    local sm_tag="sm_$(echo "$sm_raw" | tr -d '.')"
    nvidia_detail="{\"sm\":\"${sm_tag}\",\"vram_gb\":${vram_gb}}"
    if [[ "$sm_int" -ge 860 ]] && [[ "$vram_gb" -ge 8 ]]; then
      nvidia_status="green"
      nvidia_msg="SM ${sm_raw} (>= 8.6), VRAM ${vram_gb} GB (>= 8 GB)"
    else
      nvidia_status="warn"
      nvidia_msg="SM ${sm_raw}, VRAM ${vram_gb} GB — Isaac Sim recommends SM >= 8.6 and VRAM >= 8 GB"
    fi
  else
    nvidia_status="warn"
    nvidia_msg="nvidia-smi not available — GPU not detected or driver not installed"
    nvidia_detail=""
  fi
  record_check host nvidia "$nvidia_status" "$nvidia_msg" "$nvidia_detail"

  # host.jq
  if jq --version &>/dev/null; then
    record_check host jq green "$(jq --version 2>/dev/null)"
  else
    record_check host jq fail "jq not found"
  fi

  # host.xclip
  if xclip -version &>/dev/null 2>&1; then
    record_check host xclip green "xclip present"
  else
    record_check host xclip fail "xclip not found"
  fi

  # host.libfuse2
  local fuse_status fuse_msg
  if dpkg -s libfuse2 &>/dev/null 2>&1; then
    fuse_status="green"; fuse_msg="libfuse2 installed"
  elif dpkg -s libfuse2t64 &>/dev/null 2>&1; then
    fuse_status="green"; fuse_msg="libfuse2t64 installed (Ubuntu 24.04 variant)"
  else
    fuse_status="fail"; fuse_msg="libfuse2 (or libfuse2t64) not installed"
  fi
  record_check host libfuse2 "$fuse_status" "$fuse_msg"

  # host.tmux — require >= 3.2
  local tmux_ver_raw tmux_major tmux_minor tmux_status tmux_msg
  if tmux_ver_raw="$(tmux -V 2>/dev/null)"; then
    # "tmux 3.4" or "tmux 3.2a"
    tmux_major="$(echo "$tmux_ver_raw" | awk '{print $2}' | cut -d. -f1)"
    tmux_minor="$(echo "$tmux_ver_raw" | awk '{print $2}' | cut -d. -f2 | tr -dc '0-9')"
    if [[ "$tmux_major" -gt 3 ]] || { [[ "$tmux_major" -eq 3 ]] && [[ "${tmux_minor:-0}" -ge 2 ]]; }; then
      tmux_status="green"; tmux_msg="$tmux_ver_raw (>= 3.2)"
    else
      tmux_status="warn"; tmux_msg="$tmux_ver_raw — version < 3.2, some features may not work"
    fi
  else
    tmux_status="fail"; tmux_msg="tmux not found"
  fi
  record_check host tmux "$tmux_status" "$tmux_msg"
}

# ---------------------------------------------------------------------------
# Layer: dotfiles
# ---------------------------------------------------------------------------
check_dotfiles() {
  # dotfiles.wezterm
  local wez_target="${ROBOT_ROOT}/dotfiles/wezterm.lua"
  local wez_link="$HOME/.config/wezterm/wezterm.lua"
  local wez_resolved
  wez_resolved="$(readlink -f "$wez_link" 2>/dev/null || true)"
  if [[ "$wez_resolved" == "$wez_target" ]]; then
    record_check dotfiles wezterm green "readlink matches ${wez_target}"
  elif [[ -z "$wez_resolved" ]]; then
    record_check dotfiles wezterm fail "${wez_link} does not exist or is not a symlink"
  else
    record_check dotfiles wezterm fail "${wez_link} -> ${wez_resolved} (expected ${wez_target})"
  fi

  # dotfiles.tmux
  local tmux_target="${ROBOT_ROOT}/dotfiles/tmux.conf"
  local tmux_link="$HOME/.tmux.conf"
  local tmux_resolved
  tmux_resolved="$(readlink -f "$tmux_link" 2>/dev/null || true)"
  if [[ "$tmux_resolved" == "$tmux_target" ]]; then
    record_check dotfiles tmux green "readlink matches ${tmux_target}"
  elif [[ -z "$tmux_resolved" ]]; then
    record_check dotfiles tmux fail "${tmux_link} does not exist or is not a symlink"
  else
    record_check dotfiles tmux fail "${tmux_link} -> ${tmux_resolved} (expected ${tmux_target})"
  fi

  # dotfiles.xprofile
  local xp_target="${ROBOT_ROOT}/dotfiles/xprofile"
  local xp_link="$HOME/.xprofile"
  local xp_resolved
  xp_resolved="$(readlink -f "$xp_link" 2>/dev/null || true)"
  if [[ "$xp_resolved" == "$xp_target" ]]; then
    record_check dotfiles xprofile green "readlink matches ${xp_target}"
  elif [[ -z "$xp_resolved" ]]; then
    record_check dotfiles xprofile fail "${xp_link} does not exist or is not a symlink"
  else
    record_check dotfiles xprofile fail "${xp_link} -> ${xp_resolved} (expected ${xp_target})"
  fi

  # dotfiles.wezterm-keybindings
  local kb_target="${ROBOT_ROOT}/dotfiles/KEYBINDINGS.md"
  local kb_link="$HOME/.config/wezterm/KEYBINDINGS.md"
  local kb_resolved
  kb_resolved="$(readlink -f "$kb_link" 2>/dev/null || true)"
  if [[ "$kb_resolved" == "$kb_target" ]]; then
    record_check dotfiles wezterm-keybindings green "readlink matches ${kb_target}"
  elif [[ -z "$kb_resolved" ]]; then
    record_check dotfiles wezterm-keybindings fail "${kb_link} does not exist or is not a symlink"
  else
    record_check dotfiles wezterm-keybindings fail "${kb_link} -> ${kb_resolved} (expected ${kb_target})"
  fi
}

# ---------------------------------------------------------------------------
# Layer: cli
# ---------------------------------------------------------------------------
check_cli() {
  # cli.node — require major >= 20
  local node_ver node_major node_status node_msg
  if node_ver="$(node --version 2>/dev/null)"; then
    # "v20.x.y" → strip leading v, get major
    node_major="$(echo "$node_ver" | tr -d 'v' | cut -d. -f1)"
    if [[ "$node_major" -ge 20 ]]; then
      node_status="green"; node_msg="${node_ver} (major >= 20)"
    else
      node_status="warn"; node_msg="${node_ver} — major version < 20 (recommend v20+)"
    fi
  else
    node_status="fail"; node_msg="node not found"
  fi
  record_check cli node "$node_status" "$node_msg"

  # cli.claude
  if claude --version &>/dev/null 2>&1; then
    record_check cli claude green "$(claude --version 2>/dev/null | head -1)"
  else
    record_check cli claude fail "claude CLI not found"
  fi

  # cli.omc — warn (not required) if absent
  local omc_status omc_msg
  if omc --version &>/dev/null 2>&1; then
    omc_status="green"; omc_msg="$(omc --version 2>/dev/null | head -1)"
  else
    omc_status="warn"; omc_msg="omc not found — install oh-my-claudecode to enable full orchestration"
  fi
  record_check cli omc "$omc_status" "$omc_msg"

  # cli.omc-plugin — check enabledPlugins in ~/.claude/settings.json
  local plugin_status plugin_msg
  local settings_file="$HOME/.claude/settings.json"
  plugin_status="fail"
  plugin_msg="oh-my-claudecode plugin not found in ${settings_file}"
  if [[ -f "$settings_file" ]]; then
    if jq -e '(.enabledPlugins // []) | map(select(test("oh-my-claudecode"))) | length > 0' \
        "$settings_file" &>/dev/null 2>&1; then
      plugin_status="green"
      plugin_msg="oh-my-claudecode found in enabledPlugins"
    else
      # Fallback: any plugin path containing oh-my-claudecode
      if grep -q "oh-my-claudecode" "$settings_file" 2>/dev/null; then
        plugin_status="green"
        plugin_msg="oh-my-claudecode reference found in ${settings_file}"
      else
        plugin_status="warn"
        plugin_msg="oh-my-claudecode not found in ${settings_file} enabledPlugins — install omc plugin"
      fi
    fi
  else
    plugin_status="warn"
    plugin_msg="${settings_file} not found — run install.sh --step=claude first"
  fi
  record_check cli omc-plugin "$plugin_status" "$plugin_msg"

  # cli.rtk — token-compressing proxy (optional but recommended)
  local rtk_bin="$HOME/.local/bin/rtk"
  local rtk_exe=""
  if [[ -x "$rtk_bin" ]]; then rtk_exe="$rtk_bin"; elif command -v rtk &>/dev/null; then rtk_exe="$(command -v rtk)"; fi
  if [[ -z "$rtk_exe" ]]; then
    record_check cli rtk "warn" "rtk not installed — install.sh --step=cli will install"
  else
    local rtk_ver
    rtk_ver=$("$rtk_exe" --version 2>/dev/null | awk '{print $2}' || echo unknown)
    # Detect hook via ~/.claude/settings.json (rtk init --show has been seen to segfault on some builds)
    local settings_file="$HOME/.claude/settings.json"
    if [[ -f "$settings_file" ]] && jq -e '.hooks.PreToolUse // [] | map(.hooks // []) | flatten | map(.command // "") | any(. | test("rtk hook"))' "$settings_file" &>/dev/null; then
      record_check cli rtk "green" "rtk ${rtk_ver} installed + Claude Code hook registered"
    else
      record_check cli rtk "warn" "rtk ${rtk_ver} installed but hook not registered — run 'rtk init -g --auto-patch'"
    fi
  fi

  # cli.notebooklm
  if command -v notebooklm &>/dev/null; then
    record_check cli notebooklm green "$(notebooklm --version 2>/dev/null | head -1 || echo present)"
  else
    record_check cli notebooklm warn "notebooklm not found — opt-in via install.sh (no --skip-notebooklm)"
  fi
}

# ---------------------------------------------------------------------------
# Layer: claude
# ---------------------------------------------------------------------------
check_claude() {
  local claude_md="$HOME/.claude/CLAUDE.md"

  # claude.marker — assert OMC:ROBOT:START and OMC:ROBOT:END present,
  # and OMC:ROBOT:START line > OMC:END line (AC-7)
  local marker_status marker_msg
  if [[ ! -f "$claude_md" ]]; then
    marker_status="fail"
    marker_msg="${claude_md} not found"
  else
    local line_omc_end line_robot_start line_robot_end
    line_omc_end="$(grep -n '<!-- OMC:END -->' "$claude_md" 2>/dev/null | tail -1 | cut -d: -f1 || true)"
    line_robot_start="$(grep -n '<!-- OMC:ROBOT:START -->' "$claude_md" 2>/dev/null | tail -1 | cut -d: -f1 || true)"
    line_robot_end="$(grep -n '<!-- OMC:ROBOT:END -->' "$claude_md" 2>/dev/null | tail -1 | cut -d: -f1 || true)"

    if [[ -z "$line_robot_start" ]] || [[ -z "$line_robot_end" ]]; then
      marker_status="fail"
      marker_msg="OMC:ROBOT:START/END markers not found in ${claude_md} — run install.sh --step=claude"
    elif [[ -n "$line_omc_end" ]] && [[ "$line_robot_start" -le "$line_omc_end" ]]; then
      marker_status="fail"
      marker_msg="OMC:ROBOT:START (line ${line_robot_start}) is not after OMC:END (line ${line_omc_end}) — marker injection order violation (AC-7)"
    else
      marker_status="green"
      marker_msg="OMC:ROBOT block found at lines ${line_robot_start}-${line_robot_end}"
    fi
  fi
  record_check claude marker "$marker_status" "$marker_msg"

  # claude.settings-seed — teammateMode + SessionStart hook present
  local seed_status seed_msg
  local settings_file="$HOME/.claude/settings.json"
  if [[ ! -f "$settings_file" ]]; then
    seed_status="fail"
    seed_msg="${settings_file} not found — run install.sh --step=claude"
  elif ! jq empty "$settings_file" &>/dev/null 2>&1; then
    seed_status="fail"
    seed_msg="${settings_file} is not valid JSON"
  else
    local has_teammate has_session
    has_teammate="$(jq -r '.teammateMode // ""' "$settings_file" 2>/dev/null)"
    has_session="$(jq -r '(.hooks.SessionStart // []) | length' "$settings_file" 2>/dev/null)"
    if [[ -n "$has_teammate" ]] && [[ "${has_session:-0}" -gt 0 ]]; then
      seed_status="green"
      seed_msg="teammateMode=${has_teammate} and SessionStart hook(s) present (${has_session} entry/entries)"
    elif [[ -z "$has_teammate" ]]; then
      seed_status="warn"
      seed_msg="teammateMode not set — run install.sh --step=claude to apply settings seed"
    else
      seed_status="warn"
      seed_msg="SessionStart hook not found — run install.sh --step=claude to apply settings seed"
    fi
  fi
  record_check claude settings-seed "$seed_status" "$seed_msg"

  # claude.commands — save-memory.md symlinked to $ROBOT_ROOT/claude/commands/save-memory.md
  local cmd_target="${ROBOT_ROOT}/claude/commands/save-memory.md"
  local cmd_link="$HOME/.claude/commands/save-memory.md"
  local cmd_resolved
  cmd_resolved="$(readlink -f "$cmd_link" 2>/dev/null || true)"
  if [[ "$cmd_resolved" == "$cmd_target" ]]; then
    record_check claude commands green "save-memory.md symlinked to ${cmd_target}"
  elif [[ -z "$cmd_resolved" ]]; then
    record_check claude commands fail "${cmd_link} not found — run install.sh --step=claude"
  else
    record_check claude commands fail "${cmd_link} -> ${cmd_resolved} (expected ${cmd_target})"
  fi
}

# ---------------------------------------------------------------------------
# Layer: gemini
# ---------------------------------------------------------------------------
check_gemini() {
  # gemini.cli — CLI presence + version
  if ! command -v gemini &>/dev/null; then
    record_check gemini cli fail "gemini CLI not found — run install.sh --step=gemini or install manually"
    return 0
  fi
  local gver
  gver="$(gemini --version 2>/dev/null | head -1 || echo unknown)"
  record_check gemini cli green "gemini CLI present (version=${gver})"

  # gemini.omg-extension — oh-my-gemini-cli installed at pinned v0.8.1
  local omg_manifest="$HOME/.gemini/extensions/oh-my-gemini-cli/gemini-extension.json"
  local target_version="0.8.1"
  if [[ ! -f "$omg_manifest" ]]; then
    record_check gemini omg-extension fail \
      "oh-my-gemini-cli not installed (${omg_manifest} missing) — run install.sh --step=gemini"
  else
    local cur_ver
    cur_ver="$(jq -r .version "$omg_manifest" 2>/dev/null || echo unknown)"
    if [[ "$cur_ver" == "$target_version" ]]; then
      record_check gemini omg-extension green "oh-my-gemini-cli v${cur_ver} (target v${target_version})"
    else
      record_check gemini omg-extension warn \
        "oh-my-gemini-cli v${cur_ver} installed (target v${target_version}) — upgrade manually"
    fi
  fi

  # gemini.settings — settings.json is valid JSON
  local gem_settings="$HOME/.gemini/settings.json"
  if [[ ! -f "$gem_settings" ]]; then
    record_check gemini settings warn "${gem_settings} not found — run install.sh --step=gemini to seed"
  elif ! jq empty "$gem_settings" &>/dev/null 2>&1; then
    record_check gemini settings fail "${gem_settings} is not valid JSON"
  else
    local preview
    preview="$(jq -r '.general.previewFeatures // false' "$gem_settings" 2>/dev/null)"
    if [[ "$preview" == "true" ]]; then
      record_check gemini settings green "settings.json valid; general.previewFeatures=true (seed applied)"
    else
      record_check gemini settings warn \
        "settings.json valid but general.previewFeatures missing — re-run install.sh --step=gemini"
    fi
  fi

  # gemini.trusted-folders — $ROBOT_ROOT registered as TRUST_FOLDER
  local trust="$HOME/.gemini/trustedFolders.json"
  if [[ ! -f "$trust" ]]; then
    record_check gemini trusted-folders warn "${trust} not found — run install.sh --step=gemini"
  else
    local status
    status="$(jq -r --arg k "$ROBOT_ROOT" '.[$k] // "missing"' "$trust" 2>/dev/null)"
    if [[ "$status" == "TRUST_FOLDER" ]]; then
      record_check gemini trusted-folders green "${ROBOT_ROOT} registered as TRUST_FOLDER"
    else
      record_check gemini trusted-folders warn \
        "${ROBOT_ROOT} not in trustedFolders (status=${status}) — run install.sh --step=gemini"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Layer: vendor
# ---------------------------------------------------------------------------
check_vendor() {
  local vendor_dir="${ROBOT_ROOT}/vendor/isaac-sim-mcp"

  # vendor.submodule
  local sub_status sub_msg
  if [[ ! -d "$vendor_dir" ]]; then
    sub_status="fail"
    sub_msg="${vendor_dir} directory not found — run: git submodule update --init --recursive"
  else
    local head_sha gitmodules_url
    head_sha="$(git -C "$vendor_dir" rev-parse HEAD 2>/dev/null || true)"
    if [[ -z "$head_sha" ]]; then
      sub_status="fail"
      sub_msg="${vendor_dir} is not a valid git repo — submodule not initialized"
    else
      # Read pinned SHA from .gitmodules (submodule.<name>.branch or via git submodule status)
      local pinned_sha
      pinned_sha="$(git -C "$ROBOT_ROOT" submodule status vendor/isaac-sim-mcp 2>/dev/null \
        | awk '{print $1}' | tr -d '-+ ' || true)"
      if [[ -z "$pinned_sha" ]]; then
        sub_status="warn"
        sub_msg="vendor/isaac-sim-mcp checked out at ${head_sha:0:12} (could not read pinned SHA from .gitmodules)"
      elif [[ "$head_sha" == "$pinned_sha" ]]; then
        sub_status="green"
        sub_msg="vendor/isaac-sim-mcp checked out at SHA ${head_sha:0:12} (matches .gitmodules pin)"
      else
        sub_status="warn"
        sub_msg="vendor/isaac-sim-mcp at ${head_sha:0:12} but .gitmodules pins ${pinned_sha:0:12} — run: git submodule update"
      fi
    fi
  fi
  record_check vendor submodule "$sub_status" "$sub_msg"

  # vendor.patches
  local patches_dir="${ROBOT_ROOT}/patches"
  local patch_status patch_msg
  if [[ ! -d "$patches_dir" ]]; then
    patch_status="warn"
    patch_msg="patches/ directory not found — B-7 patch artifacts not yet generated"
  else
    local patch_files
    shopt -s nullglob
    patch_files=( "${patches_dir}"/*.diff )
    shopt -u nullglob
    # handle glob no-match
    if [[ ${#patch_files[@]} -eq 0 ]] || [[ ! -f "${patch_files[0]}" ]]; then
      patch_status="warn"
      patch_msg="patches/ exists but contains no *.diff files"
    else
      local manifest="${patches_dir}/MANIFEST.sha256"
      if [[ ! -f "$manifest" ]]; then
        patch_status="warn"
        patch_msg="${#patch_files[@]} *.diff file(s) present — no MANIFEST.sha256 to verify against"
      else
        local sha_check
        if sha_check="$(cd "$patches_dir" && sha256sum --check MANIFEST.sha256 2>&1)"; then
          patch_status="green"
          patch_msg="patches/*.diff sha256 chain verified (${#patch_files[@]} file(s))"
        else
          patch_status="fail"
          patch_msg="patches/MANIFEST.sha256 verification failed: ${sha_check}"
        fi
      fi
    fi
  fi
  record_check vendor patches "$patch_status" "$patch_msg"
}

# ---------------------------------------------------------------------------
# Layer: secrets
# ---------------------------------------------------------------------------
check_secrets() {
  local env_local="${ROBOT_ROOT}/.env.local"
  local ngc_status ngc_msg

  local key_in_env=false key_in_file=false helper_present=false
  local helper_name=""

  # Check NGC_API_KEY in environment (do not echo value)
  if [[ -n "${NGC_API_KEY:-}" ]]; then
    key_in_env=true
  fi

  # Check NGC_API_KEY in .env.local (non-empty value)
  if [[ -f "$env_local" ]]; then
    if grep -qE '^NGC_API_KEY=.+' "$env_local" 2>/dev/null; then
      key_in_file=true
    fi
  fi

  # Check docker credential helper in PATH
  if helper_name="$(ls /usr/local/bin/docker-credential-* /usr/bin/docker-credential-* \
        "${HOME}/.local/bin/docker-credential-*" 2>/dev/null | head -1)"; then
    if [[ -n "$helper_name" ]]; then
      helper_present=true
    fi
  fi
  # Also check generic PATH search
  if ! $helper_present; then
    if command -v docker-credential-pass &>/dev/null 2>&1 || \
       command -v docker-credential-secretservice &>/dev/null 2>&1 || \
       command -v docker-credential-osxkeychain &>/dev/null 2>&1; then
      helper_present=true
    fi
  fi

  if ($key_in_env || $key_in_file) && $helper_present; then
    ngc_status="green"
    if $key_in_env && $key_in_file; then
      ngc_msg="NGC_API_KEY in env + .env.local; credential helper present (token not echoed)"
    elif $key_in_env; then
      ngc_msg="NGC_API_KEY in shell env; credential helper present (token not echoed)"
    else
      ngc_msg="NGC_API_KEY in .env.local; credential helper present (token not echoed)"
    fi
  elif $key_in_env || $key_in_file; then
    ngc_status="warn"
    ngc_msg="NGC_API_KEY found (token not echoed) but no docker-credential-* helper in PATH — run: docker login nvcr.io"
  elif $helper_present; then
    ngc_status="warn"
    ngc_msg="docker-credential-* helper present but NGC_API_KEY not set — add to .env.local or export in shell"
  else
    ngc_status="fail"
    ngc_msg="NGC_API_KEY not set and no docker credential helper — run install.sh secrets step"
  fi
  record_check secrets ngc "$ngc_status" "$ngc_msg"
}

# ---------------------------------------------------------------------------
# Layer: templates
# ---------------------------------------------------------------------------
check_templates() {
  local docker_dir="${ROBOT_ROOT}/templates/docker"
  local required_docker_files=(
    "docker-compose.yml"
    "entrypoint-mcp.sh"
    "enable_mcp.py"
    "isaacsim.streaming.mcp.kit"
    "Dockerfile.ros2"
  )

  # templates.docker
  local missing_docker=()
  for f in "${required_docker_files[@]}"; do
    if [[ ! -f "${docker_dir}/${f}" ]]; then
      missing_docker+=("$f")
    fi
  done
  if [[ ${#missing_docker[@]} -eq 0 ]]; then
    record_check templates docker green "compose.yml + 4 support files present in templates/docker/"
  else
    record_check templates docker fail "missing in templates/docker/: ${missing_docker[*]}"
  fi

  # templates.mcp-tmpl
  local mcp_tmpl="${ROBOT_ROOT}/templates/.mcp.json.tmpl"
  local mcp_status mcp_msg
  if [[ ! -f "$mcp_tmpl" ]]; then
    mcp_status="fail"
    mcp_msg="templates/.mcp.json.tmpl not found"
  else
    # Validate as JSON after stripping ${VAR} placeholders → replace with "placeholder"
    local cleaned
    cleaned="$(sed 's/\${[^}]*}/placeholder/g' "$mcp_tmpl" 2>/dev/null)"
    if echo "$cleaned" | jq empty &>/dev/null 2>&1; then
      mcp_status="green"
      mcp_msg="templates/.mcp.json.tmpl present and valid JSON (after placeholder substitution)"
    else
      mcp_status="warn"
      mcp_msg="templates/.mcp.json.tmpl present but failed JSON validation — check for syntax errors"
    fi
  fi
  record_check templates mcp-tmpl "$mcp_status" "$mcp_msg"
}

# ---------------------------------------------------------------------------
# Layer: datafactory (optional — only if ~/robot/datafactory exists)
# ---------------------------------------------------------------------------
check_datafactory() {
  local df_dir="${HOME}/robot/datafactory"
  # Resolve via ROBOT_ROOT as well
  local df_dir2="${ROBOT_ROOT}/datafactory"

  local target_dir=""
  if [[ -d "$df_dir2" ]] || [[ -L "$df_dir2" ]]; then
    target_dir="$df_dir2"
  elif [[ -d "$df_dir" ]] || [[ -L "$df_dir" ]]; then
    target_dir="$df_dir"
  fi

  if [[ -z "$target_dir" ]]; then
    # Silent skip — datafactory not present
    return 0
  fi

  local df_status df_msg
  if (cd "$target_dir" && docker compose --profile streaming config >/dev/null 2>&1); then
    df_status="green"
    df_msg="docker compose --profile streaming config succeeded in ${target_dir}"
  else
    df_status="fail"
    df_msg="docker compose --profile streaming config failed in ${target_dir}"
  fi
  record_check datafactory config "$df_status" "$df_msg"
}

# ---------------------------------------------------------------------------
# Layer: mcp
# ---------------------------------------------------------------------------
check_mcp() {
  # mcp.github-mcp-server — check if registered in claude mcp list
  local github_status github_msg
  if command -v claude &>/dev/null; then
    if claude mcp list 2>/dev/null | grep -q "github-mcp-server"; then
      github_status="green"
      github_msg="github-mcp-server registered in user scope"
    else
      github_status="warn"
      github_msg="github-mcp-server not registered — run install.sh --step=claude"
    fi
  else
    github_status="fail"
    github_msg="claude CLI not found"
  fi
  record_check mcp github-mcp-server "$github_status" "$github_msg"

  # mcp.plugins — check 4 required plugins
  local plugins=(
    "context7@claude-plugins-official"
    "superpowers@claude-plugins-official"
    "skill-creator@claude-plugins-official"
    "oh-my-claudecode@omc"
  )
  local missing_plugins=()
  local settings_file="$HOME/.claude/settings.json"
  if [[ -f "$settings_file" ]]; then
    for p in "${plugins[@]}"; do
      if ! jq -e --arg p "$p" '.enabledPlugins[$p] == true' "$settings_file" &>/dev/null; then
        missing_plugins+=("$p")
      fi
    done
  else
    missing_plugins=("${plugins[@]}")
  fi

  if [[ ${#missing_plugins[@]} -eq 0 ]]; then
    record_check mcp plugins green "all 4 distribution plugins enabled"
  else
    record_check mcp plugins warn "missing/disabled plugins: ${missing_plugins[*]}"
  fi

  # mcp.parent-mcp-json — check ~/robot/.mcp.json existence and valid JSON
  local parent_mcp="${ROBOT_ROOT}/.mcp.json"
  local pmcp_status pmcp_msg
  if [[ -f "$parent_mcp" ]]; then
    if jq empty "$parent_mcp" &>/dev/null; then
      pmcp_status="green"
      pmcp_msg="~/robot/.mcp.json present and valid"
    else
      pmcp_status="fail"
      pmcp_msg="~/robot/.mcp.json is invalid JSON"
    fi
  else
    pmcp_status="warn"
    pmcp_msg="~/robot/.mcp.json not found — github-mcp-server might be missing config"
  fi
  record_check mcp parent-mcp-json "$pmcp_status" "$pmcp_msg"
}

# ---------------------------------------------------------------------------
# Run checks
# ---------------------------------------------------------------------------
ALL_LAYERS=( host dotfiles cli claude gemini mcp vendor secrets templates datafactory )

run_layer() {
  local layer="$1"
  case "$layer" in
    host)        check_host ;;
    dotfiles)    check_dotfiles ;;
    cli)         check_cli ;;
    claude)      check_claude ;;
    gemini)      check_gemini ;;
    mcp)         check_mcp ;;
    vendor)      check_vendor ;;
    secrets)     check_secrets ;;
    templates)   check_templates ;;
    datafactory) check_datafactory ;;
    *)
      echo "Unknown layer: $layer" >&2
      exit 1
      ;;
  esac
}

if [[ -n "$ONLY_LAYER" ]]; then
  run_layer "$ONLY_LAYER"
else
  for layer in "${ALL_LAYERS[@]}"; do
    run_layer "$layer"
  done
fi

# ---------------------------------------------------------------------------
# JSON output
# ---------------------------------------------------------------------------
emit_json() {
  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Build layers object
  local layers_json="{}"

  # Collect all layer names from recorded keys
  declare -A seen_layers
  for key in "${!RESULTS[@]}"; do
    local layer="${key%%.*}"
    seen_layers["$layer"]=1
  done

  for layer in "${!seen_layers[@]}"; do
    local layer_obj="{}"
    for key in "${!RESULTS[@]}"; do
      local key_layer="${key%%.*}"
      local key_check="${key#*.}"
      if [[ "$key_layer" != "$layer" ]]; then continue; fi
      local val="${RESULTS[$key]}"
      local status="${val%%|*}"
      local message="${val#*|}"
      # JSON-escape message
      local msg_json
      msg_json="$(printf '%s' "$message" | jq -Rs '.')"
      local check_obj
      if [[ -n "${DETAIL[$key]:-}" ]]; then
        check_obj="{\"status\":\"${status}\",\"message\":${msg_json},\"detail\":${DETAIL[$key]}}"
      else
        check_obj="{\"status\":\"${status}\",\"message\":${msg_json}}"
      fi
      layer_obj="$(echo "$layer_obj" | jq --argjson v "$check_obj" --arg k "$key_check" '. + {($k): $v}')"
    done
    layers_json="$(echo "$layers_json" | jq --argjson v "$layer_obj" --arg k "$layer" '. + {($k): $v}')"
  done

  local total=$(( COUNT_GREEN + COUNT_WARN + COUNT_FAIL ))

  jq -n \
    --arg schema "v1" \
    --arg ts "$timestamp" \
    --arg rr "$ROBOT_ROOT" \
    --argjson summary "{\"green\":${COUNT_GREEN},\"warn\":${COUNT_WARN},\"fail\":${COUNT_FAIL},\"total\":${total}}" \
    --argjson layers "$layers_json" \
    '{schema: $schema, timestamp: $ts, robot_root: $rr, summary: $summary, layers: $layers}'
}

# ---------------------------------------------------------------------------
# Human output
# ---------------------------------------------------------------------------
emit_human() {
  # Group checks by layer for ordered output
  local ordered_layers=( host dotfiles cli claude gemini mcp vendor secrets templates datafactory )
  if [[ -n "$ONLY_LAYER" ]]; then
    ordered_layers=( "$ONLY_LAYER" )
  fi

  for layer in "${ordered_layers[@]}"; do
    # Check if this layer has any results
    local has_results=false
    for key in "${!RESULTS[@]}"; do
      if [[ "${key%%.*}" == "$layer" ]]; then
        has_results=true
        break
      fi
    done
    if ! $has_results; then continue; fi

    echo -e "${C_BOLD}[${layer}]${C_RESET}"

    # Print checks for this layer (iterate by defined order where possible)
    local layer_checks=()
    for key in "${!RESULTS[@]}"; do
      if [[ "${key%%.*}" == "$layer" ]]; then
        layer_checks+=("${key#*.}")
      fi
    done

    # Sort for stable output
    IFS=$'\n' layer_checks=($(sort <<<"${layer_checks[*]}")); unset IFS

    for check in "${layer_checks[@]}"; do
      local key="${layer}.${check}"
      local val="${RESULTS[$key]}"
      local status="${val%%|*}"
      local message="${val#*|}"
      local icon
      case "$status" in
        green) icon="$(icon_green)" ;;
        warn)  icon="$(icon_warn)"  ;;
        fail)  icon="$(icon_fail)"  ;;
        *)     icon="[????]" ;;
      esac
      printf "  %s %-22s %s\n" "$icon" "$check" "$message"
    done
    echo
  done

  local total=$(( COUNT_GREEN + COUNT_WARN + COUNT_FAIL ))
  if [[ "$COUNT_FAIL" -eq 0 ]] && [[ "$COUNT_WARN" -eq 0 ]]; then
    echo -e "${C_GREEN}${C_BOLD}All checks passed: ${COUNT_GREEN} green, 0 warn, 0 fail (total ${total})${C_RESET}"
  elif [[ "$COUNT_FAIL" -eq 0 ]]; then
    echo -e "${C_YELLOW}${C_BOLD}${COUNT_GREEN} green, ${COUNT_WARN} warn, 0 fail (total ${total}) — warnings present${C_RESET}"
  else
    echo -e "${C_RED}${C_BOLD}${COUNT_GREEN} green, ${COUNT_WARN} warn, ${COUNT_FAIL} fail (total ${total}) — ACTION REQUIRED${C_RESET}"
  fi
}

# ---------------------------------------------------------------------------
# Final output dispatch
# ---------------------------------------------------------------------------
if [[ "$JSON_MODE" == "true" ]]; then
  emit_json
  exit 0
else
  emit_human
  if [[ "$COUNT_FAIL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
fi
