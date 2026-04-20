# Implementation Plan: Robot Dev OMC Setup Repo (~/robot/) — v3

> _Authored in DATAFACTORY repo on 2026-04-20. See DATAFACTORY git log for authorship history._


**Source spec:** `.omc/specs/deep-interview-robot-setup-repo.md` (ambiguity 11.25%, 6 rounds)
**Mode:** Ralplan consensus (short mode), non-interactive
**Iteration:** 3 (revised for heredoc NEW_SESSION + .gitignore hygiene pre-WIP + bash -n hook check)

---

## Requirements Summary

Create `~/robot/` as parent template repo, restructure current `DATAFACTORY/` into its first child via **symlink** (no physical move, V&V work uninterrupted), install 2-Tier wiki (`~/robot/wiki/` global + `<child>/wiki/` project-local), polish setup documentation with pain-points preserved. OMC-native composition; minimal skill/MCP set; no git submodules; isaac-sim+ros2 kept integrated inside child.

---

## RALPLAN-DR Summary (short mode)

### Principles (5)
1. **YAGNI** — ship only the structure needed now; defer custom skills/MCPs until real pain appears.
2. **OMC-native composition** — reuse `deepinit`/`wiki`/`mcp-setup`/`verify`; no shadow tooling that replicates OMC built-ins.
3. **Rollback-safe** — every mutation goes through captured SHA + backup + atomic commits; single-command revert per phase.
4. **Documentation-first** — Phase 0 Doc Audit precedes any code/file change, preserving Isaac Sim / streaming / MCP pain-points.
5. **Incremental verification** — Phase 1 smoke test (streaming + headless + ros2 profiles, `get_scene_info` + `execute_script` round-trip + `get_topics`) replayed at each phase boundary.

### Decision Drivers (top 3)
1. **V&V continuity** — existing DATAFACTORY Phase 2-5 pipeline must continue with zero downtime, zero silent regression.
2. **OMC first-use learning curve** — user is new to OMC; complexity surfaces and exploratory/known-failing features must be minimal.
3. **Pain-points preservation** — Isaac Sim 4.5.0 install / streaming client / MCP 1.27.0 patch knowledge must not regress or go stale.

### Viable Options for DATAFACTORY → robot restructure

#### Option A: Physical move (`~/Desktop/Project/DATAFACTORY` → `~/robot/datafactory/`)
- **Pros:** clean parent-child physical hierarchy; unambiguous `COMPOSE_PROJECT_NAME` inference; `realpath` consistent.
- **Cons:** invalidates cwd of every live tmux pane at once; Docker compose named volumes (`isaac_cache`) may re-create under new project name → slow first launch; rollback is another full move (risk of partial state if interrupted mid-move); Claude Code per-project auto-memory (`~/.claude/projects/-home-codelab-Desktop-Project-DATAFACTORY-`) becomes orphaned unless we rename that too.

#### Option B: Symlink (`~/robot/datafactory` → `~/Desktop/Project/DATAFACTORY`) — **SELECTED**
- **Pros:** zero V&V downtime; trivial undo (`rm symlink`); 2-Tier SessionStart hook follows symlink to load both wikis; git/docker operations continue at real path; Claude Code auto-memory stays at original project hash.
- **Cons:** dual-path mental model — user must remember both names; `COMPOSE_PROJECT_NAME` inference differs between paths (mitigated via explicit `docker/.env`); `Path.resolve()` in scripts produces real path, breaking "I'm in ~/robot/" intuition; future children may follow symlink pattern for consistency even when physical placement would be natural.

#### Option C: Reference-only (no symlink; `~/robot/PROJECTS.txt` lists children)
- **Pros:** maximum isolation; no filesystem coupling; no dual-path.
- **Cons:** parent-child relationship is soft (config lookup, not directory); future scaffolding (bootstrap-child.sh creating a new child at arbitrary location) must invent a registration protocol; mental model "look inside ~/robot/ to see children" is broken — users must open `PROJECTS.txt` every time.

### Invalidation rationale
Option A deferred because the live tmux session, docker volumes, and auto-memory hash all move at once with an interrupt-risk window. When ~/robot/ hosts 2+ children and physical grouping pays off (future), reconsider.
Option C deferred for **mental-model cost**, not technical impossibility. The 2-Tier wiki hook CAN resolve parent via a hardcoded `PARENT=$HOME/robot` env var (AC-2.1 uses this exact pattern, so it's not a hook issue — prior Critic correctly called this out). The real cost is: every child discovery requires reading an index file; `ls ~/robot/` no longer lists projects; bootstrap-child.sh becomes a registration command, not a creation command.

### Selected path: **Option B (Symlink)** for first iteration, with explicit guardrails:
1. `docker/.env` pins `COMPOSE_PROJECT_NAME=datafactory` (prevents dual-path container duplication).
2. All backup/rollback uses captured git SHAs (not `cp -a` of orphaned subdirs).
3. Step 9+10 atomized into a single commit (no SessionStart window with a dead path).
4. User guidance: new tmux panes opened at `~/robot/datafactory` are fine; existing panes pointing to real path continue working unchanged.

---

## Acceptance Criteria (testable)

### Phase 0 — Doc Audit
- [ ] **AC-0.1**: `.omc/research/doc-audit-20260420.md` exists, lists 5 audited files (`ENVIRONMENT_SETUP.md`, `QUICKSTART.md`, `robot-dev-omc-setup-guide.md`, `.memory/lessons_*.md` ×5 [post-rename: `wiki/lessons_*.md`]).
- [ ] **AC-0.2**: Audit table has **35 cells** (7 pain-points × 5 docs), each classified as `COVERED file:line_range` OR `GAP remediation_owner=<name>`. **No cell may be blank or marked "N/A"**. Pain-points enumerated:
  1. Isaac Sim 4.5.0 Docker install + NVIDIA runtime + nucleus path + RTX 5060 sm_120 iray warning
  2. WebRTC Streaming Client AppImage install + `127.0.0.1:49100` connect
  3. Docker MCP wiring (currently Non-Goal; audit records "deferred" but decision path documented)
  4. `--exec enable_mcp.py` + `set_extension_enabled()` 4.2→4.5 API patch
  5. `mcp` 1.27.0 compat (FastMCP description removed, return type fix)
  6. `Dockerfile.ros2` rosbridge + port 9090
  7. WezTerm `use_ime=true` + IBus autostart + tmux `bind '\'` workaround
- [ ] **AC-0.3**: Every `GAP` cell triggers an in-place edit in the same phase OR an explicit acceptance of "deferred with owner". At least 3 GAP cells must be closed by direct edit before Phase 1 begins.

### Phase 1 — ~/robot/ parent skeleton
- [ ] **AC-1.1**: `~/robot/` exists with `git init` done, branch=`main`, one initial commit.
- [ ] **AC-1.2**: Directory tree `{scripts/, wiki/, .claude/, .omc/{specs,plans,research}/, AGENTS.md, CLAUDE.md, README.md, .gitignore}` present. `.gitignore` exact content (embed verbatim):
  ```gitignore
  # OMC runtime (per-session state, not tracked)
  .omc/state/
  .omc/sessions/
  .omc/logs/
  .omc/notepad.md
  .omc/project-memory.json
  # OMC artifacts (tracked — design records)
  !.omc/specs/
  !.omc/plans/
  !.omc/research/

  # Data outputs / caches
  data/
  __pycache__/
  *.pyc
  .cache/

  # Env
  .env
  *.local
  ```
- [ ] **AC-1.3**: `~/robot/wiki/INDEX.md` exists, TOC links to ≥4 stub docs.
- [ ] **AC-1.4**: `~/robot/.claude/settings.json` minimally sets `teammateMode: tmux`, `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, and defines SessionStart + PostCompact hooks per AC-2.1 (2-Tier wiki cat).
- [ ] **AC-1.5**: `~/robot/AGENTS.md` navigation-only (< 80 lines) pointing to children and `wiki/INDEX.md`.
- [ ] **AC-1.6**: `claude -p "echo SessionStartOK"` run from `cd ~/robot` completes and stdout contains `SessionStartOK` (scriptable proxy for "hook fires without crash"). Hook output may be inspected via temp file if `claude -p` doesn't surface it.
- [ ] **AC-1.7**: This spec + plan **copied** (not `git mv`-ed — cross-repo history loss is explicit and acceptable) to `~/robot/.omc/specs/` and `~/robot/.omc/plans/`. Originals **stay in DATAFACTORY** as authorship provenance. A 2-line pointer is prepended to ~/robot/.omc/specs/…md: `> Authored in DATAFACTORY repo on 2026-04-20. See DATAFACTORY git log for history.`

### Phase 2 — 2-Tier wiki active
- [ ] **AC-2.1**: `~/robot/.claude/settings.json` SessionStart hook verbatim:
  ```bash
  PARENT=$HOME/robot
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PARENT")
  { echo '## Global wiki'; cat "$PARENT/wiki/INDEX.md" 2>/dev/null
    echo; echo '## Project wiki'; cat "$ROOT/wiki/INDEX.md" 2>/dev/null
    echo; echo '## AGENTS.md'; cat "$ROOT/AGENTS.md" 2>/dev/null
  } | jq -Rs '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: .}}'
  ```
- [ ] **AC-2.2**: Equivalent PostCompact hook installed (same body, different hookEventName).
- [ ] **AC-2.3**: Parent wiki has ≥4 stub files each ≥30 lines: `isaac_sim_api_patterns.md`, `ros2_bridge.md`, `omc_workflows.md`, `mcp_lessons.md`.
- [ ] **AC-2.4**: From a **freshly-spawned tmux pane** at `cd ~/robot/datafactory`, `claude -p "echo ok"` produces additionalContext text containing both `## Global wiki` (≥1 non-empty line follows) and `## Project wiki` (≥1 non-empty line follows). Verified by grepping hook stdout or a `/tmp/hook-test.log` sink.

### Phase 3 — bootstrap-child.sh
- [ ] **AC-3.1**: `~/robot/scripts/bootstrap-child.sh` is executable bash (`chmod +x`), accepts `<name>` positional arg, supports `--dry-run`.
- [ ] **AC-3.2**: Script creates `<name>/{wiki/, scripts/, .claude/, .omc/{specs,plans,research}/}` + `git init`, writes stubs (`wiki/INDEX.md`, `.claude/settings.json` inheriting parent hooks, `.mcp.json={"mcpServers":{}}`, `AGENTS.md`, `README.md`, `.gitignore`), creates `~/robot/<name>` → `<name>` symlink if `<name>` is an absolute path; else places `<name>` inside `~/robot/`. Prints next-step guidance (`/oh-my-claudecode:deepinit`, `/oh-my-claudecode:mcp-setup`).
- [ ] **AC-3.3**: `--dry-run` prints intended actions without mutating.
- [ ] **AC-3.4**: Idempotency test — `bash ~/robot/scripts/bootstrap-child.sh __test_child` runs cleanly once, running a second time without `--force` warns and exits non-zero. Cleanup: `rm -rf ~/robot/__test_child && rm -f ~/robot/__test_child` (symlink and dir both addressed).

### Phase 4 — DATAFACTORY migration (symlink-based, atomic)
- [ ] **AC-4.0**: Pre-migration SHA captured. `cd ~/Desktop/Project/DATAFACTORY && git log -1 --format=%H > .omc/state/pre-migration-sha.txt && git log -1 --format=%H > ~/robot/.omc/state/pre-migration-sha-datafactory.txt`. Both files contain the same SHA.
- [ ] **AC-4.1**: Filesystem backup exists at `~/Desktop/Project/DATAFACTORY.backup-20260420/` (`cp -a`). `du -sh` reports > 200MB (includes AppImage).
- [ ] **AC-4.2**: **ATOMIC COMMIT** — single git commit contains all of: (a) `git mv .memory wiki`, (b) `git mv wiki/MEMORY.md wiki/INDEX.md`, (c) hook rewrite in `.claude/settings.local.json`, (d) sed-updates to every `.memory/` reference across `AGENTS.md`, `robot-dev-omc-setup-guide.md`, `.gitignore`, `.claude/commands/save-memory.md`, `.omc/project-memory.json`, `.omc/state/deep-interview-state.json`. Commit message: `refactor: rename .memory/ to wiki/ + 2-Tier hooks + update all refs (atomic)`.
- [ ] **AC-4.3**: `docker/.env` file created with single line `COMPOSE_PROJECT_NAME=datafactory` (path-agnostic). Added to DATAFACTORY `.gitignore` is verified NOT to exclude `docker/.env` — commit `.env` or force-add: `git add -f docker/.env`.
- [ ] **AC-4.4**: `docker compose down -v --remove-orphans` run in DATAFACTORY **before** symlink creation (kills any stale containers, preserves named volumes `isaac_cache` unless `-v` flag intentionally used — decision: DO NOT use `-v` in this step, to preserve cache).
- [ ] **AC-4.5**: Symlink `~/robot/datafactory` → `$HOME/Desktop/Project/DATAFACTORY` created (`ln -sf`). `readlink -f ~/robot/datafactory` equals `/home/codelab/Desktop/Project/DATAFACTORY`.
- [ ] **AC-4.6**: `~/robot/AGENTS.md` navigation lists `- [datafactory/](datafactory/) — V&V pipeline (symlinked)`.
- [ ] **AC-4.7**: **Phase 1 smoke regression** (BLOCKING — see Step 12 for full suite): streaming + headless + ros2 all pass; Isaac Sim MCP responds to `get_scene_info()` AND `execute_script("from isaacsim.core.api import World; w=World(); print(w)")`; ros-mcp `connect_to_robot()` + `get_topics()` succeed.
- [ ] **AC-4.8**: `QUICKSTART.md` commands work from real path (`~/Desktop/Project/DATAFACTORY/`). Documented in Phase 6 docs: **run compose only from real path OR only from symlink path in a given time window — never from both concurrently** (hard constraint).
- [ ] **AC-4.9**: Existing tmux panes at old cwd continue to function. New panes are expected to `cd ~/robot/datafactory` — documented.

### Phase 5 — OMC workflow sanity
- [ ] **AC-5.1**: From `~/robot/` (parent), invoking `/oh-my-claudecode:deepinit` generates/updates ONLY `~/robot/AGENTS.md` and optionally `~/robot/wiki/`; it must NOT touch `~/robot/datafactory/AGENTS.md`. Pre-flight check before invocation: `[ -f ~/robot/datafactory/AGENTS.md ] && cp ~/robot/datafactory/AGENTS.md /tmp/datafactory-AGENTS.md.pre`. Post-flight: `diff /tmp/datafactory-AGENTS.md.pre ~/robot/datafactory/AGENTS.md` must be empty.
- [ ] **AC-5.2**: `.mcp.json` isolation confirmed. From `cd ~/robot/datafactory && claude mcp list` lists `isaac-sim` and `ros-mcp`; from `cd ~/robot && claude mcp list` lists only project-parent MCPs (empty or only `context7` from global).
- [ ] **AC-5.3**: `/oh-my-claudecode:wiki` invoked from parent writes to `~/robot/wiki/`; from child writes to `~/robot/datafactory/wiki/`. Smoke test: create a scratch `test_wiki_entry.md` in each location, verify write path, delete.
- [ ] **AC-5.4** (OBSERVABILITY ONLY — no action required if fails): `/oh-my-claudecode:team 3` launched from `~/robot/`; record which cwd each teammate pane ends up in and which MCPs each loads. Outcomes (pass or fail) documented in `~/robot/wiki/omc_workflows.md`. **Failure does NOT block plan completion** — Anthropic issues #16177/#4476 are open.

### Phase 6 — Documentation polish
- [ ] **AC-6.1**: `robot-dev-omc-setup-guide.md` Section 12 rewritten with actual implemented paths, verbatim hook code, symlink command, `docker/.env` pinning, bootstrap-child.sh usage.
- [ ] **AC-6.2**: New Section 13 "Troubleshooting" consolidates Isaac Sim install, streaming client, MCP wiring, tmux `bind '\'`, wezterm IME pain-points with file:line references to wiki entries. Each sub-item cites ≥1 wiki file.
- [ ] **AC-6.3**: `QUICKSTART.md` path rename (`.memory/` → `wiki/`) applied.
- [ ] **AC-6.4**: `ENVIRONMENT_SETUP.md` prepends a **Prerequisites** checklist: xclip, xsel, tmux 3.2+, IBus autostart, WezTerm `use_ime=true`, jq, docker compose 2.x, NVIDIA Container Toolkit.
- [ ] **AC-6.5**: `~/robot/README.md` ≥60 lines covering: what is this repo, how to add a child (`bootstrap-child.sh`), OMC workflow (`deepinit`/`mcp-setup`/`wiki`), 2-Tier wiki convention, dual-path mental model note, link to `wiki/INDEX.md`, link to DATAFACTORY history.

---

## Implementation Steps (ordered; concrete file paths + commands)

> Each step includes file references, exact commands, and a verification command. Default cwd = `~/Desktop/Project/DATAFACTORY/` unless noted.

### Step 1 — Phase 0 Doc Audit (in-place)
- **Files read**: `ENVIRONMENT_SETUP.md`, `QUICKSTART.md`, `robot-dev-omc-setup-guide.md`, `.memory/lessons_*.md` (5 files).
- **File write**: `.omc/research/doc-audit-20260420.md` — matrix of 7 pain-points × 5 docs = 35 cells.
- **Verification**: `awk '/\| (COVERED|GAP)/' .omc/research/doc-audit-20260420.md | wc -l` returns `35`.

### Step 2 — Fill audit gaps (≥3 in-place edits)
- **Candidates (observed stale state)**: `ENVIRONMENT_SETUP.md` Prerequisites missing xclip/xsel/tmux/IBus/jq; `QUICKSTART.md` may lack explicit `docker compose --profile headless` example; `robot-dev-omc-setup-guide.md:399` unresolved tmux prefix note.
- **Verification**: Step 1 re-run reports ≥3 GAP cells closed.

### Step 3 — Create ~/robot/ parent
- **Commands**:
  ```bash
  mkdir -p ~/robot/{scripts,wiki,.claude,.omc/{specs,plans,research}}
  cd ~/robot && git init -b main
  ```
- **File writes**: `.gitignore` (verbatim from AC-1.2), `AGENTS.md` (navigation stub), `CLAUDE.md` (short: "defaults inherited from ~/.claude/CLAUDE.md"), `README.md` (stub, filled in Step 14), `wiki/INDEX.md` (TOC), `.claude/settings.json` (per AC-1.4; hooks per AC-2.1).
- **Verification**: `ls -la ~/robot/ && jq '.hooks.SessionStart[0].hooks[0].command' ~/robot/.claude/settings.json | grep -q PARENT` returns 0.

### Step 4 — Parent wiki stubs
- **File writes** (each ≥30 lines, extracted from DATAFACTORY lessons + guide):
  - `~/robot/wiki/isaac_sim_api_patterns.md` ← `.memory/lessons_isaac_sim.md` + spec §Technical Context
  - `~/robot/wiki/ros2_bridge.md` ← `.memory/lessons_mcp.md` ROS2 + `docker/Dockerfile.ros2`
  - `~/robot/wiki/omc_workflows.md` ← `robot-dev-omc-setup-guide.md` §10-12
  - `~/robot/wiki/mcp_lessons.md` ← `.memory/lessons_mcp.md` full
- **Verification**: `for f in ~/robot/wiki/{isaac_sim_api_patterns,ros2_bridge,omc_workflows,mcp_lessons}.md; do [ "$(wc -l < "$f")" -ge 30 ] || echo "FAIL $f"; done` silent.

### Step 5 — Verify parent 2-Tier hook fires (smoke)
- **Command**: `cd ~/robot && timeout 20 claude -p "print SessionStartOK" > /tmp/robot-parent-hook.log 2>&1`.
- **Verification**: `grep -q Global /tmp/robot-parent-hook.log` (Global wiki header present).

### Step 6 — Copy (not move) this spec + plan to parent (history loss explicit)
- **Commands**:
  ```bash
  cp .omc/specs/deep-interview-robot-setup-repo.md ~/robot/.omc/specs/
  cp .omc/plans/robot-setup-repo-plan.md ~/robot/.omc/plans/
  # Insert provenance note AFTER H1 (line 2) so Markdown TOC generators still find the title at line 1
  sed -i '2i\\n> _Authored in DATAFACTORY repo on 2026-04-20. See DATAFACTORY git log for authorship history._\n' \
    ~/robot/.omc/specs/deep-interview-robot-setup-repo.md \
    ~/robot/.omc/plans/robot-setup-repo-plan.md
  (cd ~/robot && git add .omc/ && git commit -m "docs: import deep-interview spec and plan (history-loss accepted, provenance noted)")
  ```
- **Decision**: originals STAY in DATAFACTORY/.omc/ as authorship record — **not deleted**. ~/robot/ copy is a derived artifact.
- **Verification**: `test -f ~/robot/.omc/specs/deep-interview-robot-setup-repo.md && test -f ~/Desktop/Project/DATAFACTORY/.omc/specs/deep-interview-robot-setup-repo.md`.

### Step 7 — bootstrap-child.sh
- **File write**: `~/robot/scripts/bootstrap-child.sh` per AC-3.1/3.2/3.3. Include shebang `#!/usr/bin/env bash`, `set -euo pipefail`, argument parsing for `--dry-run` and `--force`, idempotency guard (`[ -d $NAME ] && { [ "$FORCE" = 1 ] || { echo "exists"; exit 2; }; }`).
- **`chmod +x`**.
- **Verification**: `bash ~/robot/scripts/bootstrap-child.sh __dryrun_test --dry-run | grep -q "mkdir"` then real run, then cleanup.

### Step 7.5 — Commit pre-existing WIP (avoid atomic-commit absorption)
- **Why**: `git status` at session start showed `M .claude/settings.local.json`, `M .memory/MEMORY.md`, untracked `.memory/lessons_tmux_wezterm.md`, `.omc/`, `robot-dev-omc-setup-guide.md`. Step 11 atomic commit would absorb all of these if the working tree is dirty, and SHA-reset rollback would destroy the modifications.
- **Commands**:
  ```bash
  cd ~/Desktop/Project/DATAFACTORY

  # (0) Update DATAFACTORY .gitignore to exclude OMC runtime state BEFORE staging .omc/
  #     (prevents ralplan-state/checkpoints/sessions/agent-replay/hud-cache from being committed)
  grep -q '# OMC runtime state' .gitignore || cat >> .gitignore <<'IGNEOF'

# OMC runtime state (per-session, not tracked)
.omc/sessions/
.omc/logs/
.omc/notepad.md
.omc/project-memory.json
# Exclude runtime subdirs under state/ but allow tracked state files
.omc/state/checkpoints/
.omc/state/sessions/
.omc/state/agent-replay-*.jsonl
.omc/state/hud-stdin-cache.json
.omc/state/ralplan-state.json
IGNEOF

  # (1) Commit WIP — explicit paths only, no `git add -A`, no blanket `.omc/`
  if [ -n "$(git status --porcelain)" ]; then
    git add .gitignore \
            .claude/settings.local.json \
            .memory/MEMORY.md \
            .memory/lessons_tmux_wezterm.md \
            robot-dev-omc-setup-guide.md \
            .omc/specs/ \
            .omc/plans/ \
            .omc/research/ 2>/dev/null || true
    # deep-interview-state.json may already be tracked (modified) — add -u picks it up
    git add -u .omc/state/deep-interview-state.json 2>/dev/null || true
    git commit -m "chore: WIP snapshot + .gitignore hygiene before ~/robot migration"
  fi
  ```
- **Verification**: `git status --porcelain | grep -v '^??' | wc -l` returns `0` (no modifications to tracked files). Remaining untracked items (if any) must be runtime state that the new `.gitignore` will skip; if unexpected untracked file appears, halt and resolve before Step 8.
- **Note**: Step 7.5 explicitly lists paths. Runtime `.omc/state/` subdirs and `.omc/project-memory.json` are now gitignored — they will NOT pollute Step 11's atomic commit.

### Step 8 — Pre-migration SHA + backup
- **Pre-flight**:
  ```bash
  # Require ≥1GB free in the parent of ~/Desktop/Project/ for the cp -a backup (DATAFACTORY + AppImage ≈ 250MB; 4x headroom).
  AVAIL=$(df -P ~/Desktop/Project | awk 'NR==2 {print $4}')
  [ "$AVAIL" -gt 1048576 ] || { echo "FATAL: <1GB free in ~/Desktop/Project partition"; exit 1; }
  ```
- **Commands**:
  ```bash
  cd ~/Desktop/Project/DATAFACTORY
  git log -1 --format=%H > .omc/state/pre-migration-sha.txt
  mkdir -p ~/robot/.omc/state
  cp .omc/state/pre-migration-sha.txt ~/robot/.omc/state/pre-migration-sha-datafactory.txt
  cp -a ~/Desktop/Project/DATAFACTORY ~/Desktop/Project/DATAFACTORY.backup-20260420
  ```
- **Verification**: `diff .omc/state/pre-migration-sha.txt ~/robot/.omc/state/pre-migration-sha-datafactory.txt` empty; `du -sh ~/Desktop/Project/DATAFACTORY.backup-20260420` ≥200MB.

### Step 9 — Stop running containers (zero concurrent container-set risk)
- **Commands**:
  ```bash
  cd ~/Desktop/Project/DATAFACTORY/docker
  docker compose down --remove-orphans
  # DO NOT add -v; preserving isaac_cache volume.
  ```
- **Verification**: `docker ps -a --filter 'name=datafactory_' -q | wc -l` returns `0`.

### Step 10 — Create docker/.env for COMPOSE_PROJECT_NAME pinning
- **Command**:
  ```bash
  echo 'COMPOSE_PROJECT_NAME=datafactory' > ~/Desktop/Project/DATAFACTORY/docker/.env
  # Force-add to git (docker/.env normally gitignored via `.env` pattern)
  cd ~/Desktop/Project/DATAFACTORY
  git add -f docker/.env
  ```
- **Verification**: `cd docker && docker compose config 2>&1 | head -5 | grep -q 'name: datafactory'`.

### Step 11 — ATOMIC migration (Phase 4 critical step)
- **Pre-flight**:
  1. Confirm Step 7.5 committed — no tracked-file modifications pending: `git status --porcelain | grep -v '^??' | wc -l` → `0`. (Untracked gitignored runtime state is allowed; a non-empty result here means an unrelated WIP slipped through.)
  2. Ensure NO live `claude` session has DATAFACTORY as cwd. User advised to pause (not close) any existing panes.
  3. Snapshot `ls ~/.claude/projects/-home-codelab-Desktop-Project-DATAFACTORY-/ > /tmp/auto-memory-pre.txt` for post-flight comparison.

- **Commands** (executed from DATAFACTORY in order, no intervening session):
  ```bash
  cd ~/Desktop/Project/DATAFACTORY

  # Safety-1: capture OMC artifact hashes BEFORE sed (detect self-mutation)
  sha256sum .omc/plans/*.md .omc/specs/*.md .omc/research/*.md 2>/dev/null \
    | tee /tmp/pre-sed-omc-artifacts.sha256

  # (a) Rename directory
  git mv .memory wiki
  git mv wiki/MEMORY.md wiki/INDEX.md

  # (b) Update every .memory/ reference, EXCLUDING OMC artifacts + backups + wiki itself
  rg -l '\.memory/' \
    --glob '!wiki/' \
    --glob '!.git/' \
    --glob '!.omc/plans/' \
    --glob '!.omc/specs/' \
    --glob '!.omc/research/' \
    --glob '!*.backup*' \
    | xargs -r -I{} sed -i 's|\.memory/|wiki/|g' {}

  # Safety-2: verify OMC artifacts bit-identical (sha256 unchanged)
  sha256sum -c /tmp/pre-sed-omc-artifacts.sha256 \
    || { echo "FATAL: OMC artifacts mutated by sed sweep"; exit 1; }

  # (c) Concrete jq rewrite of SessionStart + PostCompact hooks to 2-Tier pattern.
  #     Use a HEREDOC with quoted delimiter ('HOOKEOF') to suppress variable expansion
  #     AND avoid any bash-quote escaping — the body is taken verbatim. Bash's $()
  #     command substitution strips the trailing newline. Result: NEW_SESSION is the
  #     exact single-line shell command the hook runner will execute.
  NEW_SESSION=$(cat <<'HOOKEOF'
PARENT=$HOME/robot; ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PARENT"); { echo "## Global wiki"; cat "$PARENT/wiki/INDEX.md" 2>/dev/null; echo; echo "## Project wiki"; cat "$ROOT/wiki/INDEX.md" 2>/dev/null; echo; echo "## AGENTS.md"; cat "$ROOT/AGENTS.md" 2>/dev/null; } | jq -Rs '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: .}}'
HOOKEOF
)
  # Replace the FIRST occurrence of "SessionStart" in the hookEventName field; anchored to prevent
  # accidental replacement if future hook bodies ever reference "SessionStart" elsewhere in prose.
  NEW_POSTCOMPACT=$(printf '%s' "$NEW_SESSION" | sed '0,/hookEventName: "SessionStart"/{s//hookEventName: "PostCompact"/}')

  # Sanity: NEW_SESSION must parse as valid bash syntax before we store it
  echo "$NEW_SESSION" | bash -n || { echo "FATAL: NEW_SESSION bash syntax invalid"; exit 1; }
  echo "$NEW_POSTCOMPACT" | bash -n || { echo "FATAL: NEW_POSTCOMPACT bash syntax invalid"; exit 1; }

  jq --arg s "$NEW_SESSION" --arg p "$NEW_POSTCOMPACT" \
    '.hooks.SessionStart[0].hooks[0].command = $s
     | .hooks.PostCompact[0].hooks[0].command = $p' \
    .claude/settings.local.json > /tmp/settings.json \
    && mv /tmp/settings.json .claude/settings.local.json

  # (d) Fix .omc/project-memory.json directoryMap paths (JSON can't be reliably sed'd)
  jq '(.. | objects | select(.path? | type == "string" and test("^\\.memory/")).path) |= gsub("^\\.memory/"; "wiki/")' \
    .omc/project-memory.json > /tmp/pm.json \
    && mv /tmp/pm.json .omc/project-memory.json
  # Also update .omc/state/deep-interview-state.json if any .memory/ reference
  [ -f .omc/state/deep-interview-state.json ] && \
    sed -i 's|\.memory/|wiki/|g' .omc/state/deep-interview-state.json

  # (e) .gitignore line 26 — current content: `# .memory/` (commented, documentation of tracked item).
  #     Replace with the new convention (wiki/ tracked, documented).
  sed -i 's|^# 프로젝트 메모리 — 다른 환경 세팅용으로 버전 관리에 포함$|# 프로젝트 위키 — 다른 환경 세팅용으로 버전 관리에 포함|' .gitignore
  sed -i 's|^# \.memory/$|# wiki/|' .gitignore

  # (f) Atomic commit — explicit `git add -u` for tracked modifications only (no -A, no untracked absorption)
  git add -u
  # Explicitly add any intentional new/renamed items missed by -u (git mv already staged; belt-and-suspenders)
  git add wiki/ .omc/project-memory.json
  [ -f .omc/state/deep-interview-state.json ] && git add .omc/state/deep-interview-state.json
  git commit -m "refactor: rename .memory/ to wiki/ + 2-Tier hooks + update all refs (atomic)"
  ```

- **Verification**:
  ```bash
  # 1) Filesystem renames
  test ! -d .memory && test -d wiki && test -f wiki/INDEX.md
  # 2) No dangling .memory references outside .git history and backups
  ! rg -q '\.memory/' --glob '!.git/' --glob '!*.backup*' .
  # 3) OMC artifacts untouched (same sha256)
  sha256sum -c /tmp/pre-sed-omc-artifacts.sha256
  # 4) Hook correctly references $PARENT/wiki + $ROOT/wiki
  jq -r '.hooks.SessionStart[0].hooks[0].command' .claude/settings.local.json | grep -q 'PARENT=$HOME/robot'
  jq -r '.hooks.SessionStart[0].hooks[0].command' .claude/settings.local.json | grep -q '$ROOT/wiki/INDEX.md'
  jq -r '.hooks.PostCompact[0].hooks[0].command' .claude/settings.local.json | grep -q 'PostCompact'
  # 4.5) Stored hook commands are syntactically valid bash (catches any quoting regression)
  jq -r '.hooks.SessionStart[0].hooks[0].command' .claude/settings.local.json | bash -n
  jq -r '.hooks.PostCompact[0].hooks[0].command' .claude/settings.local.json | bash -n
  # 5) Working tree clean after atomic commit
  [ "$(git status --porcelain | wc -l)" -eq 0 ]
  ```

### Step 12 — Create symlink
- **Commands**:
  ```bash
  ln -sf "$HOME/Desktop/Project/DATAFACTORY" "$HOME/robot/datafactory"
  (cd ~/robot && echo "- [datafactory/](datafactory/) — V&V pipeline (symlinked to ~/Desktop/Project/DATAFACTORY)" >> AGENTS.md && git add AGENTS.md && git commit -m "docs: register datafactory as first child")
  ```
- **Verification**: `readlink -f ~/robot/datafactory` equals `/home/codelab/Desktop/Project/DATAFACTORY`; `ls -la ~/robot/datafactory/AGENTS.md` resolves.

### Step 13 — FULL Phase 1 smoke test regression (BLOCKING GATE)
Must pass before Phase 5 / Phase 6. On any failure → ROLLBACK (see Rollback section).
```bash
cd ~/Desktop/Project/DATAFACTORY/docker  # real path — single canonical launch path
docker compose --profile streaming up -d
sleep 30
# 0) Compose project uniqueness — catches `container_name: datafactory_isaac_sim` (hardcoded in docker-compose.yml) + dual-path collision
[ "$(docker compose ls --format json | jq 'length')" -eq 1 ] || { echo "FAIL: multiple compose projects running"; exit 1; }
# 1) Container set uniqueness (name collision guard — hardcoded container_name)
[ "$(docker ps --filter 'name=datafactory_isaac_sim' -q | wc -l)" -eq 1 ] || { echo "FAIL: duplicate containers"; exit 1; }
# 2) Isaac Sim MCP boot
docker logs datafactory_isaac_sim 2>&1 | tail -50 | grep -q "Isaac Sim MCP server started on localhost:8766" || exit 1
# 3) Headless profile also works
docker compose --profile headless up -d
sleep 10
docker compose ps | grep -q 'running' || exit 1
# 4) ROS2 + rosbridge
docker compose --profile ros2 up -d ros2
sleep 5
docker exec datafactory_ros2 bash -c "source /opt/ros/humble/setup.bash && ros2 topic list" || exit 1
# 5) WebRTC AppImage runs through symlink
file "$HOME/robot/datafactory/isaacsim-webrtc-streaming-client-1.0.6-linux-x64.AppImage" | grep -q executable || exit 1
```
- **Claude-mediated (manual in session)**: invoke `get_scene_info()`, `execute_script("from isaacsim.core.api import World; w=World(); print('World ok')")`, `connect_to_robot()`, `get_topics()`. All return without error.

### Step 14 — 2-Tier hook verified from fresh tmux pane (AC-2.4)
- **Commands**:
  ```bash
  tmux new-window -n hook-test -c ~/robot/datafactory
  tmux send-keys -t hook-test "claude -p 'print HOOK_OK' 2>&1 | tee /tmp/hook-2tier.log" Enter
  sleep 20
  tmux kill-window -t hook-test
  grep -q 'Global wiki' /tmp/hook-2tier.log && grep -q 'Project wiki' /tmp/hook-2tier.log
  ```

### Step 15 — OMC workflow sanity (Phase 5)
- AC-5.1 deepinit with pre/post AGENTS.md diff check.
- AC-5.2 `.mcp.json` isolation via `claude mcp list` from both cwds.
- AC-5.3 wiki write path test (create scratch file, verify, delete).
- AC-5.4 observational team-mode log to `~/robot/wiki/omc_workflows.md`.

### Step 16 — Polish documentation (Phase 6)
- Edit `robot-dev-omc-setup-guide.md` Section 12 (real paths, real hook code, `docker/.env` note, symlink command, dual-path warning).
- Add Section 13 Troubleshooting.
- Edit `QUICKSTART.md` `.memory/` → `wiki/`.
- Edit `ENVIRONMENT_SETUP.md` Prerequisites top section.
- Write `~/robot/README.md` per AC-6.5.

### Step 17 — Final commit + log check
- `cd ~/robot && git status && git log --oneline -10`
- `cd ~/Desktop/Project/DATAFACTORY && git status && git log --oneline -10`
- Both repos clean (no uncommitted except intentional).

---

## Risks and Mitigations (revised)

| # | Risk | Likelihood | Impact | Mitigation (concrete, no social discipline) |
|---|---|---|---|---|
| R1 | docker-compose dual-path → duplicate container set | Med | High | Step 9 `docker compose down` + Step 10 `COMPOSE_PROJECT_NAME=datafactory` in `docker/.env` + Step 13.0 compose-project uniqueness + Step 13.1 container-uniqueness assertion. **Note**: `docker-compose.yml:29,54` hardcode `container_name: datafactory_isaac_sim`/`datafactory_ros2` — `COMPOSE_PROJECT_NAME` pin doesn't override; a second concurrent `compose up` from the symlink path would fail on container-name collision (Docker error, not silent). Phase 6 docs document this as a hard constraint. |
| R2 | Phase 1 smoke regression (isaac-sim MCP / ros-mcp / WebRTC / execute_script) | Med | High | Step 13 runs all three profiles + `execute_script` round-trip + AppImage check. Any failure triggers ROLLBACK. |
| R3 | `/oh-my-claudecode:deepinit` overwrites child AGENTS.md | Low | High | AC-5.1 pre-flight copy to `/tmp`, post-flight `diff` must be empty — otherwise restore from tmp. Never run deepinit from `~/robot/datafactory/`. |
| R4 | `.omc/` partial commits to parent repo create stale state | Low | Low | `.gitignore` (AC-1.2 verbatim) excludes runtime (`state/sessions/logs/notepad.md/project-memory.json`); only specs/plans/research tracked. |
| R5 | Terminal killed mid file-move (partial git state) | Low | Med | Step 11 is atomic (single commit). Pre-step 11 tmux guidance ("pause any live claude session"). Recovery: `git reset --hard <SHA from Step 8>`. |
| R6 | SessionStart window where hook reads dead path | **Eliminated** | — | Step 11 atomizes rename + hook update + refs-sed in single commit; NO intermediate state with dead path is reachable. |
| R7 | WebRTC AppImage path dependency | Low | Low | Step 13.5 verifies AppImage executable through symlink. |
| R8 | `/team` 3-agent cross-cwd MCP actually works? | High | Low | AC-5.4 is **observability-only**, not blocking. Failure logged as known-limitation per Anthropic #16177/#4476. Does NOT block plan completion. |
| R9 | OMC first-time user confusion / stops mid-loop | Low | Med | `/oh-my-claudecode:cancel` documented. Plan non-interactive output only; user launches execution. |
| **R10** | **Claude Code per-project auto-memory orphaned** (symlink vs real path hash) | **Med** | **Low** | Documented: `~/.claude/projects/-home-codelab-Desktop-Project-DATAFACTORY-` remains at real path; accessing via symlink creates a NEW empty project dir. Mitigation: always `cd` to real path when launching `claude`, OR create a sibling symlink in `~/.claude/projects/` pointing new to old. Phase 6 docs cover this. |
| **R11** | **Existing tmux panes at old cwd unaware of new structure** | **High** | **Low** | Expected & acceptable. Old panes continue working at real path (full compatibility). New panes at `~/robot/datafactory/` get 2-Tier hook. User advised to close and reopen panes gradually. |
| **R12** | **`isaac_cache` named volume re-created under new project name** | **Low** | **Med** | `COMPOSE_PROJECT_NAME=datafactory` (Step 10) pins the project name regardless of launch path → volume name `datafactory_isaac_cache` is stable. No re-download. Verified via `docker volume ls` before/after. |
| **R13** | **Scattered `.memory/` refs not all caught** | Med | Med | Step 11(b) uses `rg -l '\.memory/'` globally + manual review of `.omc/project-memory.json` (JSON, not grepped cleanly). Verification at Step 11 asserts `! rg -q '\.memory/'` excluding .git and backups. |

---

## Verification Steps (end-to-end)

1. **Audit report 35 cells populated**: `awk '/\| (COVERED|GAP)/' .omc/research/doc-audit-20260420.md | wc -l` returns 35.
2. **Parent repo**: `git -C ~/robot log --oneline | wc -l` ≥4 commits.
3. **2-Tier hook from fresh pane**: Step 14 log contains both headers with content.
4. **Phase 1 smoke full**: Step 13 all assertions pass.
5. **bootstrap-child.sh idempotent**: Step 7 cycles cleanly.
6. **Symlink + COMPOSE_PROJECT_NAME**: `readlink -f ~/robot/datafactory` ok; `(cd ~/robot/datafactory/docker && docker compose config | grep 'name: datafactory')` ok.
7. **No orphan `.memory/` refs**: `! rg -q '\.memory/' --glob '!.git/' --glob '!*.backup*' ~/Desktop/Project/DATAFACTORY ~/robot`.
8. **AC-5.1 deepinit safe**: pre/post diff empty on `~/robot/datafactory/AGENTS.md`.
9. **`.mcp.json` isolation**: `cd ~/robot/datafactory && claude mcp list` shows isaac-sim+ros-mcp; `cd ~/robot && claude mcp list` does NOT.
10. **Final docs polished**: Section 13 troubleshooting has ≥5 sub-items with wiki file citations.

---

## Rollback Procedure (per phase, using captured SHA)

| Phase | Rollback command | Notes |
|---|---|---|
| 0 | `git -C ~/Desktop/Project/DATAFACTORY checkout -- .omc/research/ && git checkout -- <edited doc>` | Read-only audit + minor edits reverted individually |
| 1 | `rm -rf ~/robot` | Greenfield directory, nothing depends on it yet |
| 2 | `git -C ~/robot checkout -- .claude/settings.json` | Hook config only |
| 3 | `rm ~/robot/scripts/bootstrap-child.sh` | Script only |
| 4 | `rm ~/robot/datafactory` (symlink); `cd ~/Desktop/Project/DATAFACTORY && git reset --hard $(cat .omc/state/pre-migration-sha.txt)` | **SHA-based, no `cp -a` of orphaned subdirs.** If git reset disturbs working tree, fall back to `rsync -a --delete ~/Desktop/Project/DATAFACTORY.backup-20260420/ ~/Desktop/Project/DATAFACTORY/` (with trailing slashes). |
| 5 | No fs mutation performed (Phase 5 is observation-only for AC-5.4); AC-5.1 auto-rolls back via `/tmp` copy if diff non-empty | |
| 6 | `git -C ~/Desktop/Project/DATAFACTORY revert HEAD` per-commit | Doc commits small, per-commit revert safe |

**Escape hatch** — complete wipe:
```bash
rm -rf ~/robot ~/Desktop/Project/DATAFACTORY
cp -a ~/Desktop/Project/DATAFACTORY.backup-20260420 ~/Desktop/Project/DATAFACTORY
```

---

## Open Questions (for ADR after review)

- **OQ-1**: Should `~/robot/.omc/{specs,plans,research}/` be committed or gitignored? **Resolved**: committed per AC-1.2 (verbatim gitignore snippet tracks them).
- **OQ-2**: `/oh-my-claudecode:deepinit` idempotency when children have mature AGENTS.md — unknown without running it. **Mitigation**: AC-5.1 pre/post diff check enforces safety even if deepinit misbehaves.
- **OQ-3**: Claude Code auto-memory behavior through symlink — unknown. **Mitigation**: R10 documents both empirical outcomes (orphan → always real path) and workaround (sibling symlink in `~/.claude/projects/`).

---

## ADR — Architecture Decision Record

### Decision
Establish `~/robot/` as a parent template repository. Integrate existing `DATAFACTORY/` as its first child via **filesystem symlink** (`~/robot/datafactory` → `$HOME/Desktop/Project/DATAFACTORY`). Rename `DATAFACTORY/.memory/` → `DATAFACTORY/wiki/` in an atomic commit that also updates 2-Tier SessionStart/PostCompact hooks, rewrites every `.memory/` reference (excluding OMC artifacts), and pins `COMPOSE_PROJECT_NAME=datafactory`. Composed entirely from existing OMC skills (`deepinit`, `wiki`, `mcp-setup`, `verify`) with a single thin custom script `bootstrap-child.sh` for skeleton scaffolding.

### Drivers
1. **V&V continuity** — DATAFACTORY Phase 2-5 pipeline (Isaac Sim 4.5.0 camera K-matrix, Replicator domain randomization, ROS2 Δt sync) must proceed with zero downtime and zero silent regression.
2. **OMC first-use learning curve** — user is newly onboarded to OMC; feature surfaces and exploratory/known-failing paths (e.g., `/team` cross-cwd MCP issue) must be minimized or explicitly deferred.
3. **Pain-points preservation** — Isaac Sim 4.5.0 install procedure, WebRTC Streaming Client AppImage wiring, `--exec enable_mcp.py` 4.2→4.5 API patch, mcp 1.27.0 compat fix, rosbridge Dockerfile, WezTerm `use_ime=true` + IBus + tmux `bind '\'` workaround — none of these may regress or become stale.

### Alternatives considered
- **Option A: Physical move** (`~/Desktop/Project/DATAFACTORY` → `~/robot/datafactory/`) — cleaner parent-child hierarchy and unambiguous `COMPOSE_PROJECT_NAME` inference, but invalidates every live tmux pane's cwd simultaneously, may force `isaac_cache` volume re-creation under new compose project name, and orphans Claude Code per-project auto-memory (`~/.claude/projects/-home-codelab-Desktop-Project-DATAFACTORY-`). Rollback requires another full move with its own interrupt window.
- **Option C: Reference-only** (no symlink; `~/robot/PROJECTS.txt` registry) — maximum isolation and zero filesystem coupling, but parent-child is a soft config-lookup relationship; `ls ~/robot/` no longer enumerates children; `bootstrap-child.sh` must invent a registration protocol; mental model "parent holds children" breaks.

### Why chosen (Option B — Symlink)
- **Zero V&V downtime** — real path keeps working identically; existing tmux panes unaffected; Docker operations continue at real path; `isaac_cache` volume name stable (pinned `COMPOSE_PROJECT_NAME`); auto-memory hash unchanged.
- **Trivial rollback** — `rm ~/robot/datafactory` (symlink only) + `git reset --hard $(cat .omc/state/pre-migration-sha.txt)` — both are O(1) operations.
- **2-Tier wiki hook works natively** — hook resolves `PARENT=$HOME/robot` and `ROOT=$(git rev-parse --show-toplevel)`; both paths reach the same repo.
- **Architect/Critic consensus** — after 4 iterations (v0→v3), both reviewers converge on APPROVE for Option B with the explicit guardrails below.

### Consequences
**Accepted:**
- Dual-path mental model — user must remember `~/Desktop/Project/DATAFACTORY` (real) and `~/robot/datafactory` (symlink) reach the same repo; Phase 6 docs explain.
- `container_name` hardcoded in `docker-compose.yml:29,54` — `COMPOSE_PROJECT_NAME` pin doesn't override. Mitigation: documented hard constraint "never `compose up` from both paths concurrently"; Step 13.0 compose-project uniqueness assertion catches accidental dual-launch (Docker will error on name collision anyway).
- `Path.resolve()` in scripts produces the real path, not the symlink path — scripts that assert "I'm in ~/robot/…" will see the real path. Documented in R1/R10.
- Cross-repo spec/plan copy loses git history — acknowledged and noted via provenance block inserted after H1 (Step 6).

**Rejected side-effects:**
- Not removing `container_name:` lines from compose yaml (out of scope for this iteration — would require dependent tooling changes).
- Not automating doc↔config sync (deferred per spec; Phase 6 docs polish is manual first iteration).
- Not introducing custom `robot-mcp-wire` / `isaac-api-guard` / `ros2-bridge-verify` skills (YAGNI per spec constraint; may be distilled via `skill-creator` after real pain appears).

### Follow-ups
1. **After first use**: if `/team 3-agent` cross-cwd MCP genuinely fails (AC-5.4), file issue pointer to Anthropic #16177/#4476 and document in `~/robot/wiki/omc_workflows.md`.
2. **Iteration 2** (not now): if a second child project emerges, reconsider Option A (physical move) to reduce dual-path mental model; or keep symlinks uniform.
3. **Long-term**: automate doc↔config drift detection via OMC `/verify` skill wrapper or pre-commit hook (spec Phase 5+ goal).
4. **Claude Code per-project auto-memory**: observe behavior when launching `claude` from symlink path vs real path; if orphan memory proves disruptive, create sibling symlink in `~/.claude/projects/`.
5. **`container_name` removal**: revisit when an architectural change to docker-compose.yml is otherwise justified (e.g., multi-environment support).

---

## Changelog

### v1 (2026-04-20) — revised per Architect + Critic feedback
- **[CRITICAL fix]** Rollback protocol rewritten: captured git SHA in `.omc/state/pre-migration-sha.txt`, not `cp -a` of orphan subdirs.
- **[CRITICAL fix]** Step 9/10 merged into single atomic Step 11 commit (rename + hook update + all refs sed + `.omc/project-memory.json` + `.omc/state/deep-interview-state.json`). Eliminated SessionStart window.
- **[CRITICAL fix]** `docker/.env` with `COMPOSE_PROJECT_NAME=datafactory` added (Step 10) + `docker compose down` before symlink (Step 9) + container-uniqueness assertion (Step 13.1). Prevents dual-path container duplication.
- **[MAJOR fix]** Step 11(b) explicit `rg -l '\.memory/' | xargs sed -i` + manual review list for `.omc/project-memory.json` and `.omc/state/deep-interview-state.json`. Scattered refs caught.
- **[MAJOR fix]** AC-0.2/0.3 strengthened: 35 cells required, no "N/A", ≥3 GAPs must be closed by direct edit.
- **[MAJOR fix]** AC-5.4 downgraded to observability-only; R8 no longer blocking.
- **[MAJOR fix]** Option C invalidation rationale rewritten: mental-model + registration-protocol cost, not technical impossibility.
- **[MAJOR fix]** Step 13 smoke expanded: streaming + headless + ros2 profiles, `execute_script` round-trip, AppImage executable check, container uniqueness.
- **[MAJOR fix]** AC-1.2 `.gitignore` embedded verbatim (10 lines).
- **[MINOR fix]** AC-1.6 uses `claude -p` (scriptable).
- **[MINOR fix]** AC-3.4 cleanup paths aligned (`__test_child` consistent).
- **[Missing] added**: R10 (auto-memory orphan), R11 (tmux panes), R12 (isaac_cache volume), R13 (scattered refs).
- **[Spec contradiction resolved]** Cross-repo spec move uses `cp` not `git mv`; history loss explicit and noted with provenance comment.

### v2 (2026-04-20) — revised per Architect v1 REVISE + Critic v1 REJECT
- **[CRITICAL fix]** Step 11(b) sed scope narrowed with `--glob '!.omc/plans/' '!.omc/specs/' '!.omc/research/' '!*.backup*'`; sha256 guard before/after to prove OMC artifacts unmutated.
- **[CRITICAL fix]** Step 7.5 inserted — commits pre-existing WIP (`M settings.local.json`, `M .memory/MEMORY.md`, untracked lessons/spec/plan/state/guide) as a snapshot BEFORE SHA capture and atomic migration. Step 11 `git add -A` replaced with `git add -u` + explicit paths — no WIP absorption, no rollback destruction.
- **[MAJOR fix]** Step 11(c) concrete `jq` rewrite using `$NEW_SESSION`/`$NEW_POSTCOMPACT` shell variables with embedded 2-Tier hook. No "manual edit" hand-wave.
- **[MAJOR fix]** Step 11(d) — `.omc/project-memory.json` directoryMap updated via `jq` recursive path rewrite (cannot sed JSON reliably); `.omc/state/deep-interview-state.json` also explicitly sed'd if present.
- **[MAJOR fix]** Step 11(e) `.gitignore` line 26 concrete before/after: `# 프로젝트 메모리 …` → `# 프로젝트 위키 …` + `# .memory/` → `# wiki/`.
- **[MAJOR fix]** Step 13.0 — `docker compose ls | jq 'length' == 1` assertion added (catches `container_name` hardcoded collision).
- **[MAJOR fix]** R1 acknowledges `container_name` hardcoded at `docker-compose.yml:29,54`; `COMPOSE_PROJECT_NAME` alone cannot prevent collision — explicit name collision error is the safety net, Phase 6 docs document.
- **[MINOR fix]** Step 6 `sed '2i'` instead of `'1i'` (provenance after H1 preserves Markdown TOC).

### v3 (2026-04-20) — revised per Architect v2 REVISE
- **[CRITICAL fix]** Step 11(c) NEW_SESSION now constructed via quoted-delimiter HEREDOC (`<<'HOOKEOF'`). Eliminates bash 4-level quote nesting bug where `'"'"'…'"'"''` miscounted terminators, which would have stored a hook with literal single-quote chars passed to `jq -Rs` → runtime syntax error on every SessionStart. Added post-construction `bash -n` sanity checks on both NEW_SESSION and NEW_POSTCOMPACT.
- **[MAJOR fix]** Step 7.5 now updates DATAFACTORY `.gitignore` BEFORE staging — excludes `.omc/sessions/`, `.omc/logs/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/state/checkpoints/`, `.omc/state/sessions/`, `.omc/state/agent-replay-*.jsonl`, `.omc/state/hud-stdin-cache.json`, `.omc/state/ralplan-state.json`. Replaced blanket `git add .omc/` with explicit `git add .omc/specs/ .omc/plans/ .omc/research/` + `git add -u .omc/state/deep-interview-state.json`.
- **[MINOR fix]** Step 11 verification now executes stored hook commands via `bash -n` (syntax-only check) — catches any future quoting regression before Step 13 smoke.

### v3.1 (2026-04-20) — consensus polish applied (post Architect v3 PASS + Critic v3 APPROVE)
- **[MINOR fix]** Step 11 pre-flight (#1) verification uses `grep -v '^??' | wc -l` for consistency with Step 7.5's tracked-file-only gate (gitignored runtime state no longer triggers false-fail).
- **[MINOR fix]** `NEW_POSTCOMPACT` sed anchored to first occurrence: `0,/…SessionStart…/{s//…PostCompact…/}` — defensive against any future hook body containing "SessionStart" in prose.
- **[MINOR fix]** Step 8 pre-flight adds `df -P ~/Desktop/Project | awk 'NR==2 {print $4}'` ≥1GB free-space check before `cp -a` backup.
- **[NEW]** ADR section added per Ralplan final consensus protocol.

**Consensus status: APPROVED** — Architect v3 PASS, Critic v3 APPROVE, 4 iterations (v0→v3.1). Plan is execution-ready.
