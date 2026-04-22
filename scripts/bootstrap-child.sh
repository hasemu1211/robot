#!/usr/bin/env bash
# bootstrap-child.sh — scaffold a new child project under ~/robot/
#
# Usage:
#   bootstrap-child.sh <name>                           # create (bare profile)
#   bootstrap-child.sh <name> --profile=isaac+ros2      # Isaac Sim + ROS2 Docker stack
#   bootstrap-child.sh <name> --profile=ros2            # ROS2 only
#   bootstrap-child.sh <name> --force                   # overwrite existing child
#
# Template substitution variables:
#   ${COMPOSE_PROJECT_NAME}  → <name>
#   ${PROJECT_NAME}          → <name>
#   ${ROBOT_ROOT}            → resolved (env ROBOT_ROOT or git rev-parse --show-toplevel)

set -euo pipefail

resolve_robot_root() {
  if [[ -n "${ROBOT_ROOT:-}" ]]; then echo "$ROBOT_ROOT"; return 0; fi
  local anchor
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then anchor="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; else anchor="$PWD"; fi
  if git -C "$anchor" rev-parse --show-toplevel &>/dev/null; then git -C "$anchor" rev-parse --show-toplevel; return 0; fi
  echo "$HOME/robot"
}

DRY_RUN=0; FORCE=0; NAME=""; PROFILE="bare"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --profile=*) PROFILE="${1#*=}"; shift ;;
    -h|--help) sed -n '/^# Usage:/,/^# Template/p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) if [[ -z "$NAME" ]]; then NAME="$1"; shift; else echo "Unexpected extra arg: $1" >&2; exit 2; fi ;;
  esac
done

if [[ -z "$NAME" ]]; then echo "Usage: $0 <name> [--profile=isaac+ros2] [--force]" >&2; exit 2; fi

PARENT="$(resolve_robot_root)"
ROBOT_ROOT_RESOLVED="$PARENT"
TARGET_NAME="$NAME"
TARGET_PATH="$PARENT/$TARGET_NAME"

say() { echo "[bootstrap] $*"; }
run() { [[ "$DRY_RUN" = 1 ]] && echo "  DRY: $*" || eval "$*"; }

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

# 1. Directory skeleton
say "Creating directory skeleton at $TARGET_PATH"
run "mkdir -p \"$TARGET_PATH\"/{wiki,scripts,config,data,docker/ros2_ws/src,.claude/skills,.omc/{specs,plans,research,state}}"

# 2. Link robotics-agent-skills (Mandated by GEMINI.md)
if [[ -d "$PARENT/external/robotics-agent-skills" ]]; then
  say "Linking robotics-agent-skills"
  run "ln -sf \"$PARENT/external/robotics-agent-skills\" \"$TARGET_PATH/.claude/skills/robotics-agent-skills\""
fi

# 3. Apply Templates (GEMINI.md, AGENTS.md, etc.)
if [[ "$DRY_RUN" = 0 ]]; then
  # Apply substitution function
  apply_subst() {
    local src="$1"
    local dest="$2"
    sed -e "s|\${PROJECT_NAME}|$TARGET_NAME|g" \
        -e "s|\${COMPOSE_PROJECT_NAME}|$TARGET_NAME|g" \
        -e "s|\${ROBOT_ROOT}|$ROBOT_ROOT_RESOLVED|g" \
        "$src" > "$dest"
  }

  # GEMINI.md
  if [[ -f "$PARENT/templates/GEMINI.md.tmpl" ]]; then
    apply_subst "$PARENT/templates/GEMINI.md.tmpl" "$TARGET_PATH/GEMINI.md"
  fi

  # AGENTS.md
  if [[ -f "$PARENT/templates/AGENTS.md.tmpl" ]]; then
    apply_subst "$PARENT/templates/AGENTS.md.tmpl" "$TARGET_PATH/AGENTS.md"
  fi

  # wiki/INDEX.md and lesson stubs
  cat > "$TARGET_PATH/wiki/INDEX.md" <<EOF
# $TARGET_NAME Wiki — Project-Local Index
> 글로벌 지식: \`~/robot/wiki/\`.

- [Isaac Sim 레슨](lessons_isaac_sim.md)
- [ROS2 레슨](lessons_ros2.md)
- [환경/Docker 레슨](lessons_environment.md)
- [OMC/OmG 경계 레슨](lessons_omc_omg_boundary.md)
EOF
  for l in isaac_sim ros2 environment omc_omg_boundary mcp; do
    echo "# $l Lessons Learned" > "$TARGET_PATH/wiki/lessons_$l.md"
  done

  # scripts/
  if [[ -d "$PARENT/templates/scripts" ]]; then
    for s in "$PARENT/templates/scripts/"*; do
      base=$(basename "$s")
      apply_subst "$s" "$TARGET_PATH/scripts/$base"
    done
    run "chmod +x \"$TARGET_PATH/scripts/\"*"
  fi

  # docker/ stack
  if [[ "$PROFILE" != "bare" ]]; then
    docker_src="$PARENT/templates/docker"
    if [[ -d "$docker_src" ]]; then
      mkdir -p "$TARGET_PATH/docker"
      apply_subst "$docker_src/docker-compose.yml" "$TARGET_PATH/docker/docker-compose.yml"
      apply_subst "$docker_src/.env.template" "$TARGET_PATH/docker/.env"
      cp "$docker_src/Dockerfile.ros2" "$TARGET_PATH/docker/Dockerfile.ros2"
      if [[ "$PROFILE" = "isaac+ros2" ]]; then
        cp "$docker_src/entrypoint-mcp.sh" "$TARGET_PATH/docker/entrypoint-mcp.sh"
        cp "$docker_src/enable_mcp.py" "$TARGET_PATH/docker/enable_mcp.py"
        cp "$docker_src/isaacsim.streaming.mcp.kit" "$TARGET_PATH/docker/isaacsim.streaming.mcp.kit"
        chmod +x "$TARGET_PATH/docker/entrypoint-mcp.sh"
      fi
    fi
  fi

  # .mcp.json
  if [[ -f "$PARENT/templates/.mcp.json.tmpl" ]]; then
    apply_subst "$PARENT/templates/.mcp.json.tmpl" "$TARGET_PATH/.mcp.json"
  else
    echo '{"mcpServers":{}}' > "$TARGET_PATH/.mcp.json"
  fi

  # .claude/settings.json (Hierarchical Wiki Load)
  mkdir -p "$TARGET_PATH/.claude"
  cat > "$TARGET_PATH/.claude/settings.json" <<'EOF'
{
  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" },
  "teammateMode": "tmux",
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "PARENT=$HOME/robot; ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo \"$PARENT\"); { echo '## Global wiki'; cat \"$PARENT/wiki/INDEX.md\" 2>/dev/null; echo; echo '## Project wiki'; cat \"$ROOT/wiki/INDEX.md\" 2>/dev/null; echo; echo '## AGENTS.md'; cat \"$ROOT/AGENTS.md\" 2>/dev/null; } | jq -Rs '{hookSpecificOutput: {hookEventName: \"SessionStart\", additionalContext: .}}'" }] }],
    "PostCompact": [{ "hooks": [{ "type": "command", "command": "PARENT=$HOME/robot; ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo \"$PARENT\"); { echo '## Global wiki'; cat \"$PARENT/wiki/INDEX.md\" 2>/dev/null; echo; echo '## Project wiki'; cat \"$ROOT/wiki/INDEX.md\" 2>/dev/null; echo; echo '## AGENTS.md'; cat \"$ROOT/AGENTS.md\" 2>/dev/null; } | jq -Rs '{hookSpecificOutput: {hookEventName: \"PostCompact\", additionalContext: .}}'" }] }]
  }
}
EOF

  # git init
  (cd "$TARGET_PATH" && git init -b main >/dev/null 2>&1 || true)
  echo "# $TARGET_NAME" > "$TARGET_PATH/README.md"
  cp "$PARENT/.gitignore" "$TARGET_PATH/.gitignore" || true
fi

# Register in parent
run "echo '- [$TARGET_NAME/]($TARGET_NAME/) — V&V enabled child ($(date -I))' >> \"$PARENT/AGENTS.md\""

say "Scaffolded $TARGET_NAME at $TARGET_PATH"
say "Next steps: cd $TARGET_NAME && ./scripts/start-session.sh"
