# Plan: robot 레포를 공유 가능한 로봇 dev env distribution으로 (iter 2 — Planner revised)

**Source spec**: `.omc/specs/deep-interview-robot-distribution.md` (ambiguity 13.75%, PASSED)
**Mode**: consensus, short RALPLAN-DR, non-interactive
**Iteration**: 2 (addresses iter 1 Architect PASS_WITH_REVISIONS + Critic REJECTED)

## Revision Ledger (iter 1 → iter 2)

| # | Finding | Origin | Resolution |
|---|---|---|---|
| R1 | P1 "single-command" vs B-1 "user manual fork" | Arch+Critic | **B-1 revised**: `.gitmodules` points to project-owned fork (no user action). User fork only for upstream PRs (advanced). |
| R2 | P2 "zero loss" vs A-4/B-6 "symlink 제거" | Arch+Critic | **A-4/B-6 revised**: `~/robot/isaac-sim-mcp` stays as compat symlink → `vendor/isaac-sim-mcp`. datafactory `.mcp.json` continues to resolve. |
| R3 | Option 2 strawmanned (install-time failure surface asserted) | Arch+Critic | **Option 2 re-rejected honestly**: comparable failure surface, chose Option 1 for license clarity + plugin tooling + commit SHA auditability. B-7 adds `patches/*.diff` artifacts for Option 2 strength absorption. |
| R4 | settings-seed merge policy undefined | Arch+Critic | **E-2 revised**: additive-for-arrays + preserve-existing-scalars default, `--override` flag for user-requested replacement. Explicit conflict log. |
| R5 | No idempotency state-file model | Arch+Critic | **F-1 revised**: `.omc/state/install/<layer>.done` markers. `install.sh --resume` skips done layers. `git clean` survivable (documented). |
| R6 | Missing B-7 patches/*.diff | Arch | **B-7 added**: `git format-patch` from fork, committed as `vendor/isaac-sim-mcp/../patches/*.diff`. doctor.sh verifies `vendor HEAD == upstream-tag + patches/*.diff sha`. |
| R7 | ROBOT_ROOT resolver missing | Arch+Critic | **New §ROBOT_ROOT contract**: runtime resolver (`git rev-parse --show-toplevel` with `$ROBOT_ROOT` env override). Used by F-1/F-2/F-4/templates. P3 honored. |
| R8 | OMC marker collision risk | Arch+Critic | **E-0 added**: pre-flight check for existing `<!-- OMC:START -->` ... `<!-- OMC:END -->` block; use sibling `<!-- OMC:ROBOT:START/END -->` outside the block; refuse to inject if parse fails. OMC re-run preservation contract documented in `docs/INSTALL.md`. |
| R9 | AC-4 grep scope policy | Critic | **AC-4 revised**: explicit include = `scripts/ templates/ claude/ dotfiles/ vendor/ .gitmodules`; exclude = `wiki/ docs/ .omc/`. Policy rationale in plan. |
| R10 | AC-3 `config` vs `up` elision | Critic | **AC-3 split**: H-3a `config` (automated, current machine), H-3b `up` (manual, VM, logged in `docs/VERIFIED.md`). Spec downgrade noted. |
| R11 | `--with-robotics-skills` scope creep | Critic | **F-4 revised**: flag dropped from iter 2 scope (Conservative boundary). robotics-agent-skills 심링크는 install.sh E-phase에서 모든 child에 일괄 주입 대신, 사용자가 `ln -s ~/robot/external/robotics-agent-skills/* <child>/.claude/skills/`를 수동 (docs). 미래 확장은 stretch. |
| R12 | A-3 submodule vs subtree | Arch | **A-3 justified**: submodule 선택. 근거: (a) vendor/isaac-sim-mcp은 양방향 active upstream — subtree는 fetch/push 복잡; (b) 명시적 pin via SHA; (c) `--recurse-submodules` 실패 시 clean error. subtree는 robotics-agent-skills에도 고려되었으나 submodule 일관성 선택. |
| R13 | Missing risks/verification | Arch+Critic | **Risk table + Verification expanded** (아래 참조). |
| R14 | Datafactory continuity | Critic open Q | **New section "Datafactory continuity"**: 전체 마이그레이션 동안 datafactory 세션 중단 0. 심링크 유지 + `../isaac-sim-mcp` 유효 + `.mcp.json` 변경 없음. |
| R15 | external/robotics-agent-skills 전환 | Critic open Q | **A-3 revised**: 기존 `external/robotics-agent-skills/` bare clone은 `git rm -r --cached` 후 `git submodule add`로 전환. 로컬 `.git/` 유지 (clone 재사용). |

---

## Requirements Summary

`~/robot/` 레포를 5-layer distribution으로 발전 (host / dotfiles / CLI+skills / Claude+vendor / child templates). `git clone --recurse-submodules + scripts/install.sh`로 **Ubuntu 22.04 + NVIDIA GPU** 호스트에 동일한 OMC + Isaac Sim/ROS2 Docker 개발 환경 재현. Conservative boundary: vendor/isaac-sim-mcp submodule(project-owned fork), ~/.claude marker-injection, datafactory 개인 자산 유지 (심링크 보존).

## RALPLAN-DR Summary (short)

### Principles (5)
1. **Single-command reproducibility** — `clone --recurse + install.sh + doctor.sh`. 유저 수동 GitHub fork 금지 (fork는 distribution 소유).
2. **Zero loss of existing user assets** — dotfiles `.pre-robot.<ts>.bak`, ~/.claude marker-injection만, settings.json additive-merge, 기존 symlink 보존.
3. **Lesson recurrence prevention** — datafactory 하드코드 패턴 전부 `${VAR}` + 런타임 ROBOT_ROOT 리졸버. `COMPOSE_PROJECT_NAME` 파라미터화.
4. **YAGNI (public-ready scope만)** — CI/full-mirror/1Password/우분투 외 OS 등 미래 기능 제외.
5. **Ontology discipline** — 13 entities 구조 유지. 확장 없음. `--with-robotics-skills`처럼 경계 흐리는 플래그 금지.

### Decision Drivers (top 3)
1. **Portability across users** — AC-4 grep 0 히트 on code+templates+scripts.
2. **Idempotent safety** — `.omc/state/install/` 마커 + 재실행 SKIP + 레이어 롤백.
3. **Boundary discipline** — 사용자 소유 자산과 repo 소유 자산 명확 분리.

### Viable Options

**Option 1 (선호): Submodule vendored (project-owned fork) + marker-inject + B-7 patches artifacts**
- Pros: `clone --recurse` 한 번, license 명시(fork repo README에 upstream+patches 명시), 플러그인 자동 pin, 감사 가능(patches/*.diff 아티팩트가 upstream SHA vs vendor HEAD 차이 시각화).
- Cons: fork sync 오버헤드 (monthly rebase 권장). project-owned fork 소유 책임 발생.

**Option 2: patches/*.diff only + upstream SHA pin**
- Pros: 업스트림 순정성, fork 불필요.
- Cons: install.sh에 `git clone upstream && git checkout <SHA> && git apply patches/*.diff` 흐름 필요. `git apply --check` 실패 시 복구 경로 복잡 (어느 hunk가 실패했는지, rebase vs abort).
- Honest invalidation: failure surface는 Option 1과 comparable. 선택 근거 = (a) fork에 plugin 생태계(릴리즈, 이슈 트래커) 유지, (b) commit SHA를 `.gitmodules`에 명시적 pin — audit가 `git submodule status`로 즉시. Option 2는 매번 patch apply → 속도 느림. Option 1 선택.

**Option 3: 상태 유지 + docs only** — distribution 의미 없음. Round 6에서 Conservative 선택으로 기각됨. 유지.

---

## Acceptance Criteria

Spec AC-0..AC-5 계승. iter 2 세부화:

| AC | 정제된 검증 | Step |
|---|---|---|
| AC-0 | `git submodule status` → vendor/isaac-sim-mcp + external/robotics-agent-skills 모두 `+` (uninitialized) 없음 | A-3 |
| AC-1a dry-run | `install.sh --dry-run`: 어떤 파일에 쓸지 1-line per op, 실제 쓰기 0 | F-1 |
| AC-1b step | `install.sh --step=host|dotfiles|cli|claude|vendor|child`: 해당만 실행 + `.omc/state/install/<layer>.done` 마커 | F-1 |
| AC-1c idempotent | 2회 연속 실행 → 2번째는 모든 레이어 `[SKIP already-done]`, `sha256sum` 변경 0 | F-1 |
| AC-1d resume | 레이어 중 실패 시 `install.sh --resume` 재실행 → 실패한 레이어부터 재시작 | F-1 |
| AC-1e dotfiles backup | 기존 `~/.tmux.conf` 존재 시 → `.pre-robot.<ts>.bak` 생성 + `readlink ~/.tmux.conf == $ROBOT_ROOT/dotfiles/tmux.conf` | F-1, D-2 |
| AC-1f secrets | `NGC_API_KEY` 없이 `install.sh` 실행 → prompt. `NGC_API_KEY=xxx install.sh --env-from-shell` → prompt 없이 `.env.local` 작성 | F-1 |
| AC-2 doctor per-check | 각 체크 exit-code: 0=green / 1=warn / 2=fail. `doctor.sh --json` → `{layer: {check: {status, message}}}` JSON Schema 준수 | F-2 |
| AC-3a compose config | `bootstrap-child.sh testchild --profile=isaac+ros2 && docker compose -f ~/robot/testchild/docker/docker-compose.yml --profile streaming config` → 성공, 치환된 container_name=`testchild_isaac_sim` | F-4, H-3a |
| AC-3b compose up (VM, manual) | Fresh Ubuntu 22.04 VM에서 `compose up` + `get_scene_info` + `connect_to_robot` 성공 log → `docs/VERIFIED.md`에 타임스탬프+해시 기록. | H-3b |
| AC-4 portability grep | `rg -l "(datafactory\|Desktop/Project\|hasemu\|/home/codelab)" scripts/ templates/ claude/ dotfiles/ .gitmodules` → 0 히트. 제외: `wiki/ docs/ .omc/ vendor/` (이유: wiki·research는 교훈 컨텍스트 보존, vendor/는 upstream third-party 코드라 repo 소유 아님) | H-4 |
| AC-5 docs | 6 docs 존재 + `jq empty claude/settings-seed.json` + `bash -n scripts/*.sh` 전부 PASS | G-*, H-1 |
| AC-6 (new) datafactory survival | install.sh 완료 후 `cd ~/robot/datafactory && docker compose --profile streaming config` → 성공. `~/robot/isaac-sim-mcp`가 `vendor/isaac-sim-mcp`로 resolve되어 datafactory `.mcp.json`의 `../isaac-sim-mcp`가 유효 | H-6 |
| AC-7 (new) OMC marker coexist | `~/.claude/CLAUDE.md`에 기존 `<!-- OMC:START -->` 블록 + `<!-- OMC:ROBOT:START -->` 블록 모두 존재. 순서 assertion: `grep -n 'OMC:START\|OMC:END\|OMC:ROBOT:START' ~/.claude/CLAUDE.md` 결과에서 line(`OMC:ROBOT:START`) > line(`OMC:END`) — ROBOT 블록은 OMC 블록 외부(뒤)에 위치 | F-1 E-phase |

---

## ROBOT_ROOT Resolver Contract (new section)

단일 진실: **`ROBOT_ROOT` env var이 있으면 그 값**, 없으면 **`git rev-parse --show-toplevel` 결과** (install.sh, doctor.sh, bootstrap-child.sh 공통).

```bash
resolve_robot_root() {
  if [[ -n "${ROBOT_ROOT:-}" ]]; then
    echo "$ROBOT_ROOT"
    return 0
  fi
  # BASH_SOURCE 있으면 script 디렉토리, 없으면 (subshell/pipe) $PWD fallback
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
  echo "ERROR: ROBOT_ROOT 미정 — env var 세팅 또는 git repo 내에서 실행" >&2
  return 2
}
```

Template 치환 대상 (bootstrap-child.sh): `${ROBOT_ROOT}` → `resolve_robot_root` 결과로 치환. 사용자가 `~/dev/robot`에 clone해도 정상 작동. `$HOME/robot` 리터럴 사용 금지.

---

## Datafactory Continuity Contract (new section)

마이그레이션 전 기간 동안 `~/robot/datafactory` 세션 중단 0을 유지:

- `~/robot/isaac-sim-mcp` 심링크 → `vendor/isaac-sim-mcp/`로 재생성 (A-4 revised). datafactory `.mcp.json`의 `../isaac-sim-mcp` 경로는 변경 없음 (`~/robot/datafactory/../isaac-sim-mcp = ~/robot/isaac-sim-mcp → vendor/...`).
- datafactory `.mcp.json` 자체는 편집 금지 (spec: 개인 자산).
- 이주 시점: Phase B 완료 직후 H-6 검증. 검증 실패 시 rollback (submodule 해제 + 기존 심링크 복원).

---

## Implementation Steps (iter 2)

### Phase A — Repo foundation
- **A-1**: `mkdir -p vendor claude/{commands,agents} dotfiles templates/docker/scripts docs`
- **A-2**: Extend `.gitignore`: `.env.local`, `*.pre-robot.*.bak`, `.omc/state/`, `.omc/sessions/`, `.omc/logs/`, `.omc/notepad.md`, `.omc/project-memory.json`. Tracked: `.omc/{specs,plans,research}/`.
- **A-3** (justified): submodule으로 전환. 두 submodule 모두:
  - `vendor/isaac-sim-mcp` → project-owned fork URL (B-1 참조). SHA pin.
  - `external/robotics-agent-skills` → `github.com/arpitg1304/robotics-agent-skills` (upstream, third-party). 기존 bare clone은 `git rm -r --cached external/robotics-agent-skills`로 index 해제 — `git submodule add`가 기존 working-tree 디렉토리에 실패하므로 해제 순서: (i) `git rm -r --cached`, (ii) `mv external/robotics-agent-skills /tmp/rtas-tmp` 대피, (iii) `git submodule add <url> external/robotics-agent-skills`, (iv) 새 submodule이 동일 revision 이면 `/tmp/rtas-tmp` 폐기 (로컬 `.git`도 submodule 내부의 pointer 형태로 대체됨).
  - Submodule vs subtree: submodule 선택 (plugin 생태계, SHA pin, `--recurse-submodules` clean error).
- **A-4** (revised — R2): `~/robot/isaac-sim-mcp` 심링크 **유지**. `ln -sf vendor/isaac-sim-mcp ~/robot/isaac-sim-mcp`로 대상만 repo-내부로 전환 (기존: `~/Desktop/Project/isaac-sim-mcp` → 변경 후: `./vendor/isaac-sim-mcp`). datafactory `.mcp.json`의 `../isaac-sim-mcp` 경로 불변. (P2 준수)

### Phase B — Vendored isaac-sim-mcp (blocks C/F)
- **B-1** (revised — R1): Distribution이 **project-owned** fork를 하나 관리 (현재 사용자 GH 계정 하위 `robot-isaac-sim-mcp-fork`). `.gitmodules`에 이 URL 명시. 공개 사용자는 `clone --recurse` 한 번으로 동작 — 개인 fork 불필요. 상위(업스트림) PR 보내려는 기여자만 개인 fork.
- **B-2**: Fork clone (최초 1회 관리자) → 4.5.0 API 패치 커밋 (`extension.py` import 경로 3개 블록). Ref: `wiki/isaac_sim_api_patterns.md`.
- **B-3**: mcp 1.27 호환 패치 커밋 (`isaac_mcp/server.py`). Ref: `wiki/mcp_lessons.md`.
- **B-4**: `patches/CHANGELOG.md` — 커밋 이유 + 업스트림 PR 링크 + rebase 절차.
- **B-5**: `git submodule add <fork-url> vendor/isaac-sim-mcp`. Commit `.gitmodules`.
- **B-6** (revised — R2): `~/robot/isaac-sim-mcp` 심링크를 `vendor/isaac-sim-mcp`로 redirect (A-4 참조, 삭제 아님).
- **B-7** (new — R6): `cd vendor/isaac-sim-mcp && git format-patch --no-stat --zero-commit --no-signature <upstream-tag>..HEAD -o ../../patches/` → `patches/0001-isaac-4.5-api.patch` 등 생성. Commit. `--no-stat --zero-commit --no-signature` 플래그는 diff 내용을 git 버전 독립 + SHA-reproducible로 고정 (`index` 라인 제거, 커밋 SHA zero-ed). doctor.sh가 `vendor HEAD == upstream_tag + apply(patches/*.diff)` (patches sha256 chain + upstream tag SHA) 검증.

### Phase C — Docker templates (blocks F-4)
- **C-1**: `templates/docker/docker-compose.yml` — datafactory 복사 후 치환:
  - `container_name: datafactory_*` → `${COMPOSE_PROJECT_NAME}_*`
  - `../../isaac-sim-mcp` → `${ROBOT_ROOT}/vendor/isaac-sim-mcp` (ROBOT_ROOT 런타임 리졸브)
  - `ROS_DISTRO=humble` → `${ROS_DISTRO:-humble}`, `RMW_IMPLEMENTATION` 동일
- **C-2**: as-is 복사: `entrypoint-mcp.sh`, `enable_mcp.py`, `isaacsim.streaming.mcp.kit`, `Dockerfile.ros2`.
- **C-3**: `templates/docker/.env.template` — `COMPOSE_PROJECT_NAME=`, `ROS_DOMAIN_ID=0`, `ROS_DISTRO=humble`, `RMW_IMPLEMENTATION=rmw_fastrtps_cpp`, `DATA_DIR=../data`.
- **C-4**: `templates/.mcp.json.tmpl`:
  ```json
  {"mcpServers":{
    "isaac-sim":{"type":"stdio","command":"uv","args":["--directory","${ROBOT_ROOT}/vendor/isaac-sim-mcp","run","isaac_mcp/server.py"],"env":{}},
    "ros-mcp":{"type":"stdio","command":"uvx","args":["ros-mcp","--transport=stdio"],"env":{}}
  }}
  ```
- **C-5**: `templates/scripts/clean_storage.sh` — datafactory 복사.
- **C-6**: `templates/AGENTS.md.tmpl` — bootstrap stub 확장 (MCP 섹션, Phase 섹션 자리표시자 + `${COMPOSE_PROJECT_NAME}` 등 placeholder).

### Phase D — Dotfiles
- **D-1**: 복사 + 정화:
  - `~/.config/wezterm/wezterm.lua` → `dotfiles/wezterm.lua`
  - `~/.tmux.conf` → `dotfiles/tmux.conf`
  - `~/.xprofile` → `dotfiles/xprofile`
  - 각 파일에서 사용자명/경로 grep → 있으면 경고.
- **D-2**: `dotfiles/README.md` — 심링크 매핑 표 + manual merge 지침.

### Phase E — Claude marker-injection
- **E-0** (new — R8): install.sh 실행 시 `~/.claude/CLAUDE.md` 파싱 pre-flight. **알고리즘**: line-based state machine (regex only, markdown AST 불필요):
  1. 전체 라인 스캔 — `<!-- OMC:START -->`, `<!-- OMC:END -->`, `<!-- OMC:ROBOT:START -->`, `<!-- OMC:ROBOT:END -->` 4 토큰의 line number 수집.
  2. **Reject 조건**: 같은 토큰 ≥2회 등장 / `OMC:END` line < `OMC:START` line / `OMC:ROBOT:END` line < `OMC:ROBOT:START` line / START without END (unmatched) / OMC:ROBOT 블록이 OMC 블록 내부 위치 (AC-7 위반).
  3. **Accept + update**: 기존 `OMC:ROBOT:*` 블록 존재 → 해당 line range in-place 교체 (idempotent).
  4. **Accept + insert**: `OMC:ROBOT:*` 미존재 → `OMC:END` 다음 라인 (없으면 EOF) 에 append.
  5. **Reject path**: `.pre-robot.<ts>.bak` 백업 후 exit 2 + 사용자에게 `docs/INSTALL.md` §manual-recovery 포인터.
- **E-1**: `claude/CLAUDE-marker.md` — `<!-- OMC:ROBOT:START -->` ... `<!-- OMC:ROBOT:END -->` 블록. 본문: 2-Tier wiki 포인터, ROBOT_ROOT 변수 명시, robot-specific agent 진입점. 기존 OMC 블록 **외부에** 위치 (append after).
- **E-2** (revised — R4): `claude/settings-seed.json` — merge policy:
  - **Arrays (e.g., `hooks.SessionStart[]`)**: additive — seed 항목이 사용자 항목과 JSON-equal 하지 않으면 append. 사용자 기존 hook 유지.
  - **Scalars (e.g., `teammateMode`)**: preserve-existing — 사용자 값 유지. `--override` 플래그 시 seed 값 적용.
  - Merge 결과 diff를 `.omc/logs/settings-merge-<ts>.log`에 기록.
  - 실패 시 원본 `settings.json.pre-robot.<ts>.bak` 복원.
- **E-3**: `claude/commands/save-memory.md` — 일반화 (경로를 auto-memory `~/.claude/projects/<cwd-hash>/memory/`로 switch + manual fallback으로 `.omc/notepad.md` 언급).

### Phase F — Scripts
- **F-1** (revised — R5): `scripts/install.sh` (layer orchestrator):
  - Flags: `--dry-run`, `--step=<layer>`, `--yes`, `--env-from-shell`, `--resume`, `--force-os`, `--override` (settings merge).
  - Pre-check: `lsb_release -c | grep -q jammy` (abort unless `--force-os`).
  - `sudo -v` + keepalive 백그라운드.
  - 각 레이어:
    1. Pre-condition 확인 (`.omc/state/install/<layer>.done` 존재 + sha 일치 → SKIP).
    2. 실행.
    3. Post-verify (doctor layer check) → 성공 시 `.omc/state/install/<layer>.done`에 sha 기록.
    4. 실패 시 `.omc/state/install/<layer>.fail` + 로그 + exit 1.
  - `--resume`: 마지막 `.fail` 레이어부터.
  - `.omc/state/`는 gitignored → `git clean -fdx` 후엔 전체 재설치. 문서화.
  - `.env.local` 부재 + not tty + not `--env-from-shell` → fail with instruction.
- **F-2** (revised): `scripts/doctor.sh` — AC-2 체크 함수화. 각 체크 exit 0/1/2. `--json` JSON Schema:
  ```json
  {"schema":"v1","layers":{
    "host":{"docker":{"status":"green","message":"..."},"nvidia":{...},"jq":{...},"xclip":{...},"libfuse2":{...},"tmux":{...}},
    "dotfiles":{"wezterm":{...},"tmux":{...},"xprofile":{...}},
    "cli":{"node":{...},"claude":{...},"omc":{...},"omc-plugin":{...}},
    "claude":{"marker":{...},"settings-seed":{...},"commands":{...}},
    "vendor":{"patches":{"status":"green","message":"vendor HEAD sha == upstream-tag + patches chain"}},
    "secrets":{"ngc":{"status":"green","message":"credential-helper present (token not echoed)"}},
    "templates":{"docker":{...},"mcp":{...}},
    "datafactory":{"config":{"status":"green","message":"compose config 성공"}}
  }}
  ```
  `secrets.ngc` = `.env.local`에 `NGC_API_KEY=` 존재 또는 shell에 export, + `docker-credential-*` helper presence (token value는 echo 안 함). `datafactory` layer = AC-6 (datafactory 있을 때만 check).
- **F-3**: `scripts/merge-dotfiles.sh` — 대화형, 각 dotfile 대해 `[k]eep / [r]eplace / [m]erge / [s]kip`.
- **F-4** (revised — R11): `scripts/bootstrap-child.sh` 확장:
  - `--profile=isaac+ros2|ros2|bare` 플래그.
  - 템플릿 치환: `${COMPOSE_PROJECT_NAME}` → child-name, `${ROBOT_ROOT}` → `resolve_robot_root`.
  - `--with-robotics-skills` 플래그 **제거** (iter 2). 대신 `docs/ROBOTICS_SKILLS.md`에 manual 심링크 절차.
  - `.mcp.json` = `templates/.mcp.json.tmpl` 치환 결과.
  - `docker/` = `templates/docker/*` 복사 + compose.yml 치환.
- **F-5**: `scripts/promote.sh` 유지.

### Phase G — Docs
- **G-1**: `README.md` — 3-min quickstart + mermaid flowchart + links to 5 docs.
- **G-2**: `docs/INSTALL.md` — install.sh 각 step 상세 + OMC 마커 공존 계약 + idempotency state-file 설명.
- **G-3**: `docs/HOST_PREREQUISITES.md` — ENVIRONMENT_SETUP.md §1 추출.
- **G-4**: `docs/WINDOWS_GUIDE.md` — WSL2 포인터, 스코프 외 명시.
- **G-5**: `docs/MERGE_DOTFILES.md` — merge-dotfiles.sh 사용 + 수동 diff.
- **G-6**: `docs/VERIFIED.md` — doctor.sh 현 머신 baseline + fresh VM 실행 로그 (AC-3b) 기록.
- **G-7** (new): `docs/ROBOTICS_SKILLS.md` — external/robotics-agent-skills 심링크 수동 주입 절차.

### Phase H — Verification (AC-gate)
- **H-1**: `scripts/install.sh --dry-run` → 각 step 의도 출력, 파일 쓰기 0.
- **H-2**: `scripts/doctor.sh` 현 머신 baseline PASS (모든 레이어 green 기대, datafactory 레이어 포함).
- **H-3a**: `scripts/bootstrap-child.sh testchild --profile=isaac+ros2 --dry-run` + 실제 `testchild` 생성 → `docker compose config` 성공. `grep testchild_isaac_sim testchild/docker/docker-compose.yml` → 치환 확인.
- **H-3b** (new — R10): Fresh Ubuntu 22.04 VM에서 `clone + install.sh + bootstrap-child testchild + docker compose up + get_scene_info + connect_to_robot` 성공 log → `docs/VERIFIED.md`에 기록 (manual, 한 번).
- **H-4** (revised — R9): AC-4 portability grep (정책 포함).
- **H-5**: `.gitignore` 검증 — `.env.local`, `*.pre-robot.*.bak` 존재.
- **H-6** (new — R14): datafactory survival — install.sh 후 `cd ~/robot/datafactory && docker compose --profile streaming config` 성공, `~/robot/isaac-sim-mcp` → `vendor/isaac-sim-mcp`로 resolve.
- **H-7** (new — R13): install.sh 실패 복구 테스트:
  - (a) `install.sh` 정상 성공 → 모든 `.done` 마커 존재.
  - (b) `install.sh --step=claude` 중 인위적 fail 주입 → `.fail` 마커, resume 시 해당 레이어부터 재시작.
  - (c) `install.sh --resume` 완료 → 전체 성공.
- **H-8** (new — R13): jq merge 시나리오 (6 fixtures):
  - (a) 빈 `~/.claude/settings.json` → seed가 통째로 채움.
  - (b) 사용자 `teammateMode: auto` + seed `tmux` → preserve (user 유지), `--override` 시 tmux 교체.
  - (c) 사용자 existing SessionStart hook + seed hook → array additive (중복 JSON-equal 아니면 append, 기존 유지).
  - (d) **invalid JSON** (trailing comma / unescaped quote) → `jq empty` fail → merge abort + `.bak` 복원 + user에게 수동 복구 안내.
  - (e) **type mismatch** (사용자 `teammateMode: ["auto","tmux"]` array, seed는 string `"tmux"`) → preserve user + warning log + `docs/INSTALL.md` type-mismatch 섹션 포인터.
  - (f) **nested object hook equality** (같은 hook 객체인데 key 순서만 다름) → `jq --sort-keys` canonical form 후 dedup. False duplicate 방지.
- **H-9** (new — R13): OMC 마커 preservation — 현 머신에서 `omc-setup` 재실행 (또는 mock) 후 `<!-- OMC:ROBOT:START -->` 블록 유지 확인. 업스트림 OMC v4.14+ 출시 시 재검증 (VERIFIED.md 노트).

---

## Risks and Mitigations (expanded)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| apt step Ubuntu 24.04/Debian silently 실패 | Medium | High | `lsb_release -c` == jammy, `--force-os` 명시적 override + WARNING 출력 |
| ~/.claude/CLAUDE.md OMC 마커 merge 충돌 | Medium | High | E-0 pre-flight + 별도 `<!-- OMC:ROBOT:... -->` 블록 + `.bak` backup |
| **OMC 재설치 시 ROBOT 마커 삭제** (new — R8) | Medium | High | E-1이 OMC 블록 외부에 append. `docs/INSTALL.md`에 OMC 재설치 시 복구 절차 (`install.sh --step=claude`). OMC 업스트림 contract 미문서화 — 업스트림 이슈 제기. |
| **settings.json array hook 사일런트 덮어쓰기** (new — R4) | Medium | High | E-2 additive merge default + `--override` 명시. Merge log `.omc/logs/settings-merge-*.log`. |
| isaac-sim-mcp submodule fork 업스트림 rebase 충돌 | Medium | Medium | `patches/CHANGELOG.md` + `upstream-sync.sh` (stretch). B-7 patches/*.diff 아티팩트로 diff 투명성. |
| NGC 토큰 `.env.local` commit 실수 | Low | Critical | `.gitignore` + pre-commit hook (`grep NGC_API_KEY=`) + docs 경고 |
| bootstrap-child dual-path container 충돌 재발 | Low | Medium | `COMPOSE_PROJECT_NAME` 파라미터화 + F-4 치환 검증 + doctor.sh에 compose project 유일성 check |
| 사용자 wezterm.lua 크게 다름 | High | Low | `.pre-robot.<ts>.bak` + `merge-dotfiles.sh` |
| **ROBOT_ROOT 리졸버 일관성 실패** (new — R7) | Low | Medium | 단일 함수 `resolve_robot_root` 모든 스크립트 공유. doctor.sh가 모든 치환된 파일에서 `$HOME/robot` 리터럴 grep → 0 기대. |
| **external/robotics-agent-skills .git/ 전환 충돌** (new — R15) | Low | Medium | `git rm -r --cached` 후 submodule add, 로컬 `.git/` 유지. A-3에 명시. |
| **idempotency state-file `git clean` 소실** (new — R5) | Low | Low | `.omc/state/`는 gitignored — clean 후 전체 재설치 정상. `docs/INSTALL.md`에 문서화. |
| docker-compose dual-path (lesson h) | Medium | Medium | `COMPOSE_PROJECT_NAME` + "real-path-only" 명시 + doctor.sh에 `docker compose ls` 프로젝트 이름 수 assertion |
| vendor submodule SHA drift | Low | Medium | doctor.sh vendor 레이어: `git -C vendor/isaac-sim-mcp rev-parse HEAD == gitmodules에 pin된 SHA` |
| **Concurrent install.sh invocation** (new) | Low | Medium | `.omc/state/install/.lock` `flock` 획득 (`exec 200>.omc/state/install/.lock && flock -n 200 || exit 1`). 중복 실행 감지 시 즉시 exit. |
| **sudo keepalive 고아 프로세스** (new) | Medium | Low | `trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT INT TERM`. 메인 install.sh 종료 시 자동 정리. |
| **project-owned fork bus-factor** (new) | Medium | Medium | fork 레포에 최소 2인 maintainer 권한 부여. 업스트림 PR merge로 diff 축소 유지. |

---

## Verification Steps (expanded — 9 items)

1. **H-1** dry-run → 쓰기 0 검증
2. **H-2** 현 머신 doctor.sh PASS (datafactory layer 포함)
3. **H-3a** bootstrap-child config 검증 + `testchild_*` 치환 검증
4. **H-3b** (manual) VM `up` + MCP ping → `docs/VERIFIED.md` 기록
5. **H-4** AC-4 portability grep (포함/제외 정책 준수)
6. **H-5** .gitignore 항목 검증
7. **H-6** datafactory survival (compose config)
8. **H-7** install.sh 실패/resume 복구 테스트 (3 시나리오)
9. **H-8** jq merge 3 시나리오 fixture 테스트
10. **H-9** OMC 마커 preservation (현 머신 + VERIFIED.md 노트)

모든 verification H-1~H-6 + H-8은 자동. H-3b, H-7, H-9는 수동/기록형.

---

## ADR — Architectural Decision Record

### Decision
Distribution ships a **project-owned submodule fork** of `omni-mcp/isaac-sim-mcp` at `vendor/isaac-sim-mcp/` with `patches/*.diff` artifacts for supply-chain audit. `~/.claude/` integration is **marker-based (additive-inject)** — sibling block outside existing OMC marker. `~/robot/isaac-sim-mcp` symlink is **preserved**, retargeted into `vendor/`, so datafactory continues operating unchanged. Install via idempotent layered `install.sh` with `.omc/state/install/<layer>.done` markers; verification via `doctor.sh` JSON-schema'd layer checks.

### Drivers
1. Portability across users (AC-4 grep ≤ 0 hits).
2. Idempotent + resumable install (AC-1c/d).
3. Boundary discipline (user assets preserved: dotfiles backup, settings additive-merge, datafactory unaffected).
4. License clarity (fork repo declares upstream + patches).

### Alternatives considered
- **Option 2 — patches/*.diff only + upstream SHA pin**: failure surface comparable to Option 1, but each install runs `git apply` (speed + fragility). Option 1 chosen for ease of SHA audit (`git submodule status`) + plugin ecosystem (releases, issues). Option 2's strength absorbed via B-7 (patches artifacts alongside submodule).
- **Option 3 — status quo + docs only**: distribution scope not achieved. Rejected at spec Round 6 (Conservative boundary).
- **subtree instead of submodule** (A-3): subtree fetch/push 복잡, SHA pin 불명확. submodule 선택.
- **Full `~/.claude/` mirror (Maximalist)**: user assets destruction. Rejected at spec Round 6.
- **CPU fallback / wider OS**: YAGNI, spec §Non-goals.

### Why chosen
- Option 1 + B-7 patches artifacts = **Option 1 UX (single clone) + Option 2 audit trail**. Synthesis of Architect's antithesis without abandoning user's stated preference.
- Preserving `~/robot/isaac-sim-mcp` 심링크 retargeted = **zero downtime** for datafactory + no P2 violation.
- Marker-injection (additive-merge) = sustainable against `omc-setup` re-runs as long as ROBOT 블록이 OMC 블록 외부에 위치.

### Consequences
- Positive: public 사용자가 `clone --recurse + install.sh` 한 번에 작동. Supply-chain audit 가능 (patches/*.diff). datafactory 유저 영향 0. idempotent 재실행 안전.
- Negative: project-owned fork 관리 책임 발생 (월 1회 upstream sync rebase 권장). OMC 업스트림 marker-preservation contract 미문서화 (리스크 매트릭스에 표시).
- Neutral: robotics-agent-skills submodule 전환은 1회 이주 작업 (A-3).

### Follow-ups
- `upstream-sync.sh` 자동화 (stretch, iter 3 고려)
- OMC 업스트림에 marker-preservation contract 이슈 제기
- `docs/VERIFIED.md` fresh VM 실행 기록 수집 (H-3b)
- NGC 외 추가 secret (예: HuggingFace token) 확장 시 `.env.template` 업데이트 정책
- 다국어 docs (현재 한국어/영어 혼용) — 영어 통일 여부 결정
- **H-6 `docker compose config` 이 `docker login nvcr.io` 없이 작동하는지 확인** — 미작동 시 login-first pre-requisite로 문서화
- **H-9 OMC 재설치 시뮬레이션 방식 구체화** — real `/oh-my-claudecode:omc-setup` 재실행 vs mock 선택 (Phase H 구현 시점에 결정)
- **project-owned fork bus-factor** — 추가 maintainer 초대, 월간 upstream sync cadence 확정

---

## Changelog

### iter 2 → iter 2 final (Architect PASS + Critic APPROVED_WITH_IMPROVEMENTS 병합)
- AC-4 grep 명령 수정 — `vendor/` 제외 이유 명시, `vendor/.gitmodules` 중복 제거.
- AC-7 순서 assertion shell 명령 추가 — `line(OMC:ROBOT:START) > line(OMC:END)`.
- `resolve_robot_root` BASH_SOURCE-empty fallback 강화 ($PWD anchor).
- A-3 submodule 전환 시 `.git/` working-tree 처리 절차 명시 (mv /tmp → submodule add → 폐기).
- B-7 patches `git format-patch --no-stat --zero-commit --no-signature` 로 SHA-reproducible 고정.
- E-0 line-based state machine 알고리즘 5단계 구체 명시 (regex, markdown AST 불필요).
- F-2 doctor.sh JSON schema에 `secrets.ngc` (credential helper check) 명시적 레이어 추가.
- H-8 jq merge fixture 3 → 6 확장 (invalid JSON, type mismatch, nested equality).
- Risk table 3 row 추가 — concurrent install lockfile, sudo keepalive trap, fork bus-factor.
- ADR Follow-ups 3 항목 추가 — docker login 전제, OMC 재설치 mock 방식, fork bus-factor.

### iter 1 → iter 2

iter 2는 iter 1의 모든 Architect PASS_WITH_REVISIONS + Critic REJECTED 지적을 revision ledger R1~R15로 흡수. 주요 변경:
- **A-4/B-6**: 심링크 제거 → 유지 (compat). P2 준수.
- **B-1/A-3**: user 수동 fork → project-owned fork. P1 준수.
- **B-7 신규**: patches/*.diff 아티팩트. Option 2 강점 흡수.
- **E-0 신규**: OMC 마커 pre-flight.
- **E-2**: merge policy 명시 (additive-arrays + preserve-scalars + `--override`).
- **F-1**: idempotency state-file model + `--resume`.
- **F-4**: `--with-robotics-skills` 제거 (스코프 discipline).
- **ROBOT_ROOT resolver** 단일화.
- **AC-3 split**: config (자동) + up (VM 수동).
- **AC-4 scope policy**: include/exclude 명시.
- **AC-6/7 신규**: datafactory survival + OMC marker coexist.
- **Risk table**: 4 신규 (OMC 재설치 삭제, settings 배열 덮어쓰기, ROBOT_ROOT 리졸버, submodule 전환 충돌).
- **Verification**: H-3b/H-6/H-7/H-8/H-9 신규 (VM up, datafactory survival, 복구, merge fixture, 마커 preservation).
- **ADR 추가** — short mode 요구.
- **Datafactory Continuity Contract** 신규 섹션.
- **ROBOT_ROOT Contract** 신규 섹션.
