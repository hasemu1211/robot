#!/usr/bin/env bash
# bootstrap-child.sh — scaffold a new child project under ~/robot/
#
# Usage:
#   bootstrap-child.sh <name>                           # create (bare profile)
#   bootstrap-child.sh <name> --profile=isaac+ros2      # Isaac Sim + ROS2 Docker stack
#   bootstrap-child.sh <name> --profile=ros2            # ROS2 only
#   bootstrap-child.sh <name> --profile=bare            # minimal scaffold (default)
#   bootstrap-child.sh /absolute/path/to/repo           # register existing repo as symlink
#   bootstrap-child.sh <name> --dry-run                 # print plan without executing
#   bootstrap-child.sh <name> --force                   # overwrite existing child
#
# Outputs (create mode):
#   ~/robot/<name>/
#     ├── wiki/INDEX.md
#     ├── scripts/
#     ├── .claude/settings.json  (inherits 2-Tier hooks)
#     ├── .omc/{specs,plans,research}/
#     ├── .mcp.json              (empty for bare; isaac+ros2/ros2: templates/.mcp.json.tmpl 치환)
#     ├── AGENTS.md              (templates/AGENTS.md.tmpl 치환)
#     ├── README.md
#     ├── .gitignore
#     └── docker/                (isaac+ros2 or ros2 only)
#         ├── docker-compose.yml (${COMPOSE_PROJECT_NAME}, ${ROBOT_ROOT} 치환)
#         ├── .env               (.env.template 치환)
#         ├── Dockerfile.ros2
#         ├── entrypoint-mcp.sh  (isaac+ros2 only)
#         ├── enable_mcp.py      (isaac+ros2 only)
#         └── isaacsim.streaming.mcp.kit (isaac+ros2 only)
#
# Template substitution variables (applied to compose.yml/.env/.mcp.json/AGENTS.md):
#   ${COMPOSE_PROJECT_NAME}  → <name>
#   ${PROJECT_NAME}          → <name>
#   ${ROBOT_ROOT}            → resolved (env ROBOT_ROOT or git rev-parse --show-toplevel)

set -euo pipefail

# ── ROBOT_ROOT resolver (shared with install.sh / doctor.sh) ──
resolve_robot_root() {
  if [[ -n "${ROBOT_ROOT:-}" ]]; then echo "$ROBOT_ROOT"; return 0; fi
  local anchor
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    anchor="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  else
    anchor="$PWD"
  fi
  if git -C "$anchor" rev-parse --show-toplevel &>/dev/null; then
    git -C "$anchor" rev-parse --show-toplevel; return 0
  fi
  echo "$HOME/robot"  # sensible default for distribution convention
}

DRY_RUN=0
FORCE=0
NAME=""
PROFILE="bare"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)       DRY_RUN=1; shift ;;
    --force)         FORCE=1; shift ;;
    --profile=*)     PROFILE="${1#*=}"; shift ;;
    -h|--help)
      sed -n '/^# Usage:/,/^# Template/p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    -*) echo "Unknown flag: $1" >&2; exit 2 ;;
    *)
      if [[ -z "$NAME" ]]; then NAME="$1"; shift
      else echo "Unexpected extra arg: $1" >&2; exit 2
      fi
      ;;
  esac
done

case "$PROFILE" in
  bare|ros2|isaac+ros2) ;;
  *) echo "Unknown profile: $PROFILE (allowed: bare, ros2, isaac+ros2)" >&2; exit 2 ;;
esac

if [[ -z "$NAME" ]]; then
  echo "Usage: $0 <name-or-absolute-path> [--dry-run] [--force]" >&2
  exit 2
fi

# Detect mode: symlink (absolute path to existing dir) vs create (relative name)
PARENT="$(resolve_robot_root)"
ROBOT_ROOT_RESOLVED="$PARENT"
if [[ "$NAME" = /* ]] && [[ -d "$NAME" ]]; then
  MODE="symlink"
  TARGET_NAME="$(basename "$NAME")"
  TARGET_PATH="$PARENT/$TARGET_NAME"
  SYMLINK_SRC="$NAME"
else
  MODE="create"
  TARGET_NAME="$NAME"
  TARGET_PATH="$PARENT/$TARGET_NAME"
  SYMLINK_SRC=""
fi

say() { echo "[bootstrap] $*"; }
run() { [[ "$DRY_RUN" = 1 ]] && echo "  DRY: $*" || eval "$*"; }

say "Mode: $MODE"
say "Target: $TARGET_PATH"
[[ "$MODE" = "symlink" ]] && say "Symlink source: $SYMLINK_SRC"

# Idempotency guard
if [[ -e "$TARGET_PATH" || -L "$TARGET_PATH" ]]; then
  if [[ "$FORCE" = 1 ]]; then
    say "WARN: $TARGET_PATH exists. --force specified, will overwrite."
    run "rm -rf \"$TARGET_PATH\""
  else
    echo "ERROR: $TARGET_PATH already exists. Use --force to overwrite." >&2
    exit 2
  fi
fi

if [[ "$MODE" = "symlink" ]]; then
  say "Creating symlink $TARGET_PATH → $SYMLINK_SRC"
  run "ln -sf \"$SYMLINK_SRC\" \"$TARGET_PATH\""
  say "Appending to ~/robot/AGENTS.md Children section"
  run "echo '- [$TARGET_NAME/]($TARGET_NAME/) — registered via symlink to $SYMLINK_SRC' >> \"$PARENT/AGENTS.md\""
  cat <<EOF

Next steps:
  cd $TARGET_PATH
  /oh-my-claudecode:deepinit          # (if AGENTS.md not already comprehensive)
  /oh-my-claudecode:mcp-setup         # (if .mcp.json not already configured)

EOF
  exit 0
fi

# MODE = create
say "Creating directory skeleton at $TARGET_PATH"
run "mkdir -p \"$TARGET_PATH\"/{wiki,scripts,.claude,.omc/specs,.omc/plans,.omc/research}"

if [[ "$DRY_RUN" = 0 ]]; then
  # wiki/INDEX.md stub
  cat > "$TARGET_PATH/wiki/INDEX.md" <<EOF
# $TARGET_NAME Wiki — Project-Local Index

> $TARGET_NAME 프로젝트 고유 교훈. 크로스-프로젝트 지식은 \`~/robot/wiki/\`.

## 교훈

<!-- \`/oh-my-claudecode:wiki\`가 여기 추가 -->

## 프로젝트 상태

<!-- Phase 진행도, TODO -->
EOF

  # .claude/settings.json — inherits 2-Tier hooks from parent-style (same hook body)
  cat > "$TARGET_PATH/.claude/settings.json" <<'EOF'
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "tmux",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "PARENT=$HOME/robot; ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo \"$PARENT\"); { echo '## Global wiki'; cat \"$PARENT/wiki/INDEX.md\" 2>/dev/null; echo; echo '## Project wiki'; cat \"$ROOT/wiki/INDEX.md\" 2>/dev/null; echo; echo '## AGENTS.md'; cat \"$ROOT/AGENTS.md\" 2>/dev/null; } | jq -Rs '{hookSpecificOutput: {hookEventName: \"SessionStart\", additionalContext: .}}'"
          }
        ]
      }
    ],
    "PostCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "PARENT=$HOME/robot; ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo \"$PARENT\"); { echo '## Global wiki'; cat \"$PARENT/wiki/INDEX.md\" 2>/dev/null; echo; echo '## Project wiki'; cat \"$ROOT/wiki/INDEX.md\" 2>/dev/null; echo; echo '## AGENTS.md'; cat \"$ROOT/AGENTS.md\" 2>/dev/null; } | jq -Rs '{hookSpecificOutput: {hookEventName: \"PostCompact\", additionalContext: .}}'"
          }
        ]
      }
    ]
  }
}
EOF

  # .mcp.json — empty for bare, else templates/.mcp.json.tmpl 치환
  MCP_TMPL="$PARENT/templates/.mcp.json.tmpl"
  mcp_tmpl="$MCP_TMPL"
  if [[ "$PROFILE" != "bare" && -f "$mcp_tmpl" ]]; then
    sed -e "s|\${ROBOT_ROOT}|$ROBOT_ROOT_RESOLVED|g" \
        -e "s|\${PROJECT_NAME}|$TARGET_NAME|g" \
        -e "s|\${COMPOSE_PROJECT_NAME}|$TARGET_NAME|g" \
        "$mcp_tmpl" > "$TARGET_PATH/.mcp.json"
    say "  .mcp.json from templates/.mcp.json.tmpl (profile=$PROFILE)"
  else
    echo '{"mcpServers":{}}' > "$TARGET_PATH/.mcp.json"
  fi

  # AGENTS.md — templates/AGENTS.md.tmpl if present, else inline stub
  agents_tmpl="$PARENT/templates/AGENTS.md.tmpl"
  if [[ -f "$agents_tmpl" ]]; then
    sed -e "s|\${PROJECT_NAME}|$TARGET_NAME|g" \
        -e "s|\${COMPOSE_PROJECT_NAME}|$TARGET_NAME|g" \
        -e "s|\${ROBOT_ROOT}|$ROBOT_ROOT_RESOLVED|g" \
        "$agents_tmpl" > "$TARGET_PATH/AGENTS.md"
  else
    cat > "$TARGET_PATH/AGENTS.md" <<EOF
# $TARGET_NAME — Project Instructions

> Child of \`~/robot/\`. Global knowledge: \`~/robot/wiki/\`. Project-local: \`./wiki/\`.

## 개요

<!-- 프로젝트 목적, 범위 -->

## 환경

<!-- 하드웨어, OS, 컨테이너 -->

## MCP 서버 (.mcp.json)

<!-- \`/oh-my-claudecode:mcp-setup\`으로 설정 -->

## 시작 방법

\`\`\`bash
cd $TARGET_PATH
claude
\`\`\`

세션 시작 시 2-Tier wiki 자동 로드: \`~/robot/wiki/INDEX.md\` + \`./wiki/INDEX.md\`.
EOF
  fi

  # docker/ stack from templates (profile=isaac+ros2 or ros2)
  if [[ "$PROFILE" != "bare" ]]; then
    docker_src="$PARENT/templates/docker"
    if [[ ! -d "$docker_src" ]]; then
      say "WARN: $docker_src missing — docker/ stack skipped"
    else
      mkdir -p "$TARGET_PATH/docker"
      # compose.yml + .env — always substitute
      sed -e "s|\${COMPOSE_PROJECT_NAME}|$TARGET_NAME|g" \
          -e "s|\${ROBOT_ROOT}|$ROBOT_ROOT_RESOLVED|g" \
          "$docker_src/docker-compose.yml" > "$TARGET_PATH/docker/docker-compose.yml"
      sed -e "s|\${COMPOSE_PROJECT_NAME}|$TARGET_NAME|g" \
          -e "s|\${ROBOT_ROOT}|$ROBOT_ROOT_RESOLVED|g" \
          "$docker_src/.env.template" > "$TARGET_PATH/docker/.env"
      # Dockerfile.ros2 — ros2 / isaac+ros2 both need it
      cp "$docker_src/Dockerfile.ros2" "$TARGET_PATH/docker/Dockerfile.ros2"
      # Isaac-specific files — isaac+ros2 only
      if [[ "$PROFILE" = "isaac+ros2" ]]; then
        cp "$docker_src/entrypoint-mcp.sh" "$TARGET_PATH/docker/entrypoint-mcp.sh"
        cp "$docker_src/enable_mcp.py" "$TARGET_PATH/docker/enable_mcp.py"
        cp "$docker_src/isaacsim.streaming.mcp.kit" "$TARGET_PATH/docker/isaacsim.streaming.mcp.kit"
        chmod +x "$TARGET_PATH/docker/entrypoint-mcp.sh"
      fi
      say "  docker/ stack from templates/docker/ (profile=$PROFILE)"
    fi
  fi

  # README.md stub
  cat > "$TARGET_PATH/README.md" <<EOF
# $TARGET_NAME

Child project of \`~/robot/\`.

설계 및 OMC 워크플로우는 \`AGENTS.md\` 및 \`~/robot/README.md\` 참조.
EOF

  # .gitignore
  cat > "$TARGET_PATH/.gitignore" <<'EOF'
# OMC runtime
.omc/state/
.omc/sessions/
.omc/logs/
.omc/notepad.md
.omc/project-memory.json
# OMC artifacts (tracked)
!.omc/specs/
!.omc/plans/
!.omc/research/

# Caches / data
data/
__pycache__/
*.pyc
.cache/

# Env
.env
*.local
EOF

  # Git init
  (cd "$TARGET_PATH" && git init -b main >/dev/null 2>&1 || true)
fi

# Register in parent AGENTS.md Children section
run "echo '- [$TARGET_NAME/]($TARGET_NAME/) — new child (scaffolded $(date -I))' >> \"$PARENT/AGENTS.md\""

say "Created $TARGET_PATH"

cat <<EOF

Next steps:
  cd $TARGET_PATH
  # Initial commit
  git add -A && git commit -m "feat: bootstrap $TARGET_NAME as child of ~/robot/"

  # OMC workflows
  /oh-my-claudecode:deepinit          # Hierarchical AGENTS.md
  /oh-my-claudecode:mcp-setup         # Project-local MCP wiring
  /oh-my-claudecode:wiki              # Add project-local lessons to wiki/

EOF
