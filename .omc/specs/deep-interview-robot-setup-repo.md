# Deep Interview Spec: Robot Dev OMC Setup Repo (~/robot/)

> _Authored in DATAFACTORY repo on 2026-04-20. See DATAFACTORY git log for authorship history._


## Metadata

- Interview ID: `robot-setup-repo-20260420`
- Rounds: 6
- Final Ambiguity Score: **11.25%**
- Type: brownfield (DATAFACTORY/OMC 기존 구조 의존)
- Generated: 2026-04-20
- Threshold: 20% (0.2, 기본값)
- Status: **PASSED**
- Challenge modes used: Contrarian (R4)

## Clarity Breakdown

| Dimension | Score | Weight | Weighted |
|---|---|---|---|
| Goal Clarity | 0.90 | 0.35 | 0.315 |
| Constraint Clarity | 0.90 | 0.25 | 0.225 |
| Success Criteria | 0.88 | 0.25 | 0.220 |
| Context Clarity | 0.85 | 0.15 | 0.128 |
| **Total Clarity** | | | **0.888** |
| **Ambiguity** | | | **0.1125 (11.25%)** |

## Goal

`~/robot/`을 **로봇 개발용 부모 템플릿 레포**로 생성하고, 기존 `DATAFACTORY/`를 `~/robot/`의 첫 자식 프로젝트로 재정렬한다. 2-Tier wiki(글로벌 + 프로젝트-로컬), OMC-native 워크플로우(`deepinit`·`mcp-setup`·`team`·`wiki`), pain-point 중심의 고도화된 setup 문서 체계를 갖춘다. DATAFACTORY의 V&V 작업(Phase 2-5 예정)은 이관 후 중단 없이 이어진다.

## Constraints

- **OMC-native 우선** — 기존 OMC 스킬 composition, 새 custom 도구는 최소 (bootstrap 스크립트 1개 수준).
- **QUICKSTART.md 현재 동작 보존** — streaming/headless/ros2 compose profile, Isaac Sim 4.5.0 워크플로우 regression 금지.
- **DATAFACTORY V&V 작업 진행 중단 없이 이관** — `.mcp.json`, `docker/`, Phase 1 산출물, SessionStart 훅 모두 유지.
- **Wiki = 2-Tier** — `~/robot/wiki/` (글로벌) + `<child>/wiki/` (프로젝트-로컬). 디렉토리 위치가 scope 역할.
- **`.memory/` → `wiki/` rename** — OMC `/wiki` 스킬 컨벤션 정합.
- **git submodule 사용하지 않음** — child = 독립 git repo, flat 구조.
- **Isaac Sim + ROS2는 child 내부에 통합 유지** — 별도 submodule 분리 X (YAGNI).
- **구현 ordering: Doc Audit 먼저 → Scaffold/Migration → (장기) Sync 자동화** — pain-points 누락 여부 확인이 선행.
- **Sync 메커니즘은 1차에는 수동 규율 + 체크리스트**, 장기 이상형은 B(CI/hook drift 경고). A(doc-driven config)는 비목표.
- **하드웨어 제약 상속** — RTX 5060 (8GB, Blackwell sm_120), 16GB RAM, ~80GB 여유 스토리지.
- **한국어 IME + WezTerm + tmux 3.2+ 환경** — `use_ime=true`, IBus, xclip 필수.
- **OMC 산출물은 per-repo scoping** — parent(`~/robot/.omc/`)와 child(`~/robot/datafactory/.omc/`) 분리. 크로스-repo sync 없음.
- **Skill/MCP 인벤토리 = 최소 세트(A)** — 글로벌 enabled 플러그인(context7, superpowers, skill-creator, oh-my-claudecode)만 사용. 새 skill 생성 X, 새 MCP 추가 X. 실제 pain 드러나면 skill-creator로 증류.

## Non-Goals (first iteration)

- ros2 / isaac-sim 별도 git submodule 분리 (나중, 필요성 생기면).
- Doc-driven config 자동화 (AGENTS.md 파싱 → MCP attach 자동 생성).
- Docker MCP 도입 (당장 불필요).
- 웹 서치 MCP (Exa 등) 추가.
- Obsidian MCP / LightRAG 통합.
- CI/hook 기반 drift 자동 감지 (장기 목표로만 기록).
- `/oh-my-claudecode:team` pipeline full orchestration 설계 (tmux teammate 모드는 이미 구성, 활용만).
- 새 dummy child 프로젝트 생성 (DATAFACTORY가 첫 child 겸 검증 대상).
- Docker MCP 활성화 (Round 6에서 deferred).
- WebSearch/Exa MCP 활성화 (Round 6에서 deferred).
- robot-전용 커스텀 skill 사전 생성 (`robot-mcp-wire`, `isaac-api-guard`, `ros2-bridge-verify` 등 — 실사용 pain 드러난 뒤 skill-creator로 증류).

## Acceptance Criteria

### Phase 0: Doc State Audit (선행)
- [ ] `ENVIRONMENT_SETUP.md`, `QUICKSTART.md`, `robot-dev-omc-setup-guide.md`, `.memory/lessons_*.md` 5개 문서 각각 audit 리포트 작성 (`.omc/research/doc-audit-20260420.md`).
- [ ] 다음 pain-point가 문서에 존재하는지 확인 (없으면 보강):
  - Isaac Sim 4.5.0 컨테이너 설치 (Docker NVIDIA runtime, nucleus 경로, RTX 5060 sm_120 iray 경고 무시)
  - WebRTC Streaming Client AppImage 설치 및 127.0.0.1:49100 연결
  - Docker MCP 연결(현재는 미구현)과 향후 추가 경로
  - `--exec enable_mcp.py` + `set_extension_enabled()` 방식 (4.2 → 4.5 API 패치)
  - mcp 1.27.0 호환 (FastMCP description 제거, 리턴 타입)
  - rosbridge Dockerfile + 포트 9090
  - wezterm `use_ime=true` + IBus autostart + tmux `bind '\'` 회피
- [ ] 누락 항목 최소 1개 이상 보강 혹은 "all covered" 증명.

### Phase 1: ~/robot/ 부모 스켈레톤
- [ ] `~/robot/` 디렉토리 생성 + `git init`.
- [ ] 뼈대: `~/robot/{scripts/, wiki/, .claude/, AGENTS.md, CLAUDE.md, README.md, .gitignore}`.
- [ ] `~/robot/wiki/INDEX.md` 생성 (글로벌 KB 인덱스 stub).
- [ ] `~/robot/.claude/settings.json` — `teammateMode: tmux`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (글로벌 설정 상속 확인).
- [ ] `~/robot/AGENTS.md` — 네비게이션 전용 (얇음, 각 child가 자체 AGENTS.md 보유).
- [ ] `cd ~/robot && claude` 진입 시 AGENTS.md + wiki/INDEX.md 자동 로드 확인.
- [ ] **현재 spec 파일 이관** — `DATAFACTORY/.omc/specs/deep-interview-robot-setup-repo.md` → `~/robot/.omc/specs/` (parent-level 설계 산출물이므로). git log 보존용 `git mv` 사용.
- [ ] **OMC 산출물 분리 검증** — `~/robot/.omc/`에서 skill 실행 시 `~/robot/.omc/`에만 기록되고, `~/robot/datafactory/.omc/`에서 실행 시 child 경로에만 기록되는지 확인.

### Phase 2: 2-Tier Wiki 동작
- [ ] SessionStart 훅 확장 — `~/robot/wiki/INDEX.md` + `<cwd>/wiki/INDEX.md` 둘 다 cat해서 additionalContext 주입.
- [ ] 글로벌에는 공통 지식 (`isaac_sim_api_patterns.md`, `ros2_bridge.md`, `omc_workflows.md`, `mcp_lessons.md` 등 stub 최소 4개).
- [ ] PostCompact 훅도 동일하게 확장.

### Phase 3: bootstrap 스크립트
- [ ] `~/robot/scripts/bootstrap-child.sh <name>` 작성 — 작업 내용:
  - `mkdir <name>/{wiki, scripts, .claude}` + `git init`
  - `<name>/wiki/INDEX.md` stub
  - `<name>/.claude/settings.json` stub (권한 allowlist 템플릿)
  - `<name>/.mcp.json` stub (비어있는 `{"mcpServers":{}}`)
  - `<name>/AGENTS.md` stub
  - `<name>/README.md` stub
  - 끝에 안내: `/oh-my-claudecode:deepinit`, `/oh-my-claudecode:mcp-setup` 가이드 출력
- [ ] dry-run 모드 (`--dry-run`) 지원 — 실제 생성 없이 plan만 출력.

### Phase 4: DATAFACTORY 이관
- [ ] `DATAFACTORY/.memory/` → `DATAFACTORY/wiki/` rename, `MEMORY.md` → `INDEX.md`.
- [ ] 기존 `.memory/lessons_*.md` → `wiki/lessons_*.md` 그대로 이동.
- [ ] `DATAFACTORY/.claude/settings.json` 의 SessionStart/PostCompact 훅 업데이트 (경로 변경 + 글로벌 wiki 로드).
- [ ] `.mcp.json` 보존, `docker/` 그대로.
- [ ] **Phase 1 검증 재실행** — `docker compose --profile streaming up` 성공, `get_scene_info()` 응답, `ros-mcp connect_to_robot` 성공, `get_topics()` 응답.
- [ ] DATAFACTORY를 `~/robot/`의 child로 배치 — 옵션 선택지 2개 중 1개:
  - (a) `~/robot/datafactory/` 심볼릭 링크 또는
  - (b) DATAFACTORY 물리 이동 `~/Desktop/Project/DATAFACTORY/` → `~/robot/datafactory/`
  - 선택은 writing-plans 단계에서 확정.

### Phase 5: OMC 워크플로우 검증
- [ ] `~/robot/`에서 `/oh-my-claudecode:deepinit` 실행 → 계층적 AGENTS.md 생성/업데이트.
- [ ] DATAFACTORY child에서 `/oh-my-claudecode:mcp-setup` 또는 기존 `.mcp.json`이 그대로 격리 로드됨을 확인.
- [ ] `/oh-my-claudecode:team` 3-agent 모드 — 각 teammate가 tmux 다른 pane에서 기동, 각 pane이 다른 cwd이면 다른 MCP 활성됨을 확인 (실험적, 실패 시 가능성만 기록하고 비목표로 이월 가능).
- [ ] `/oh-my-claudecode:wiki` 스킬이 `~/robot/wiki/` 와 `<child>/wiki/` 둘 다 읽고 쓸 수 있음을 확인.

### Phase 6: 문서 고도화
- [ ] `robot-dev-omc-setup-guide.md` 섹션 12 업데이트 — 이번 이터레이션 반영 (실제 구조, 실제 경로, 실제 hook 코드).
- [ ] 새 섹션 13 — **Troubleshooting** (Isaac Sim install, 스트리밍 클라이언트, Docker MCP wiring 등 pain-points 통합).
- [ ] QUICKSTART.md 경로 변경 (.memory → wiki) 반영.
- [ ] ENVIRONMENT_SETUP.md에 누락된 사전요구사항 (xclip, xsel, tmux 3.2+, IBus autostart 등) 보강.

## Assumptions Exposed & Resolved

| 가정 | 도전 방식 | 해결 |
|---|---|---|
| "DATAFACTORY를 child로 바로 migration 필요" | 브레인스토밍 Q1 (A/B/C) | 확정: C scope (full migration in iteration 1) |
| "git submodule 구조가 필요" (가이드 섹션 3) | scope decomposition Q3 | **거부** — flat 구조, 독립 git repo per child |
| "isaac-sim + ros2는 별도 submodule로 분리해야" | scope decomposition | **거부** — DATAFACTORY 내부 통합 유지 (docker compose profile 구조 깨짐 방지) |
| "custom scaffold 스크립트는 OMC 자동 init과 충돌" | brainstorming | 해결: bootstrap은 뼈대만, 내용은 deepinit/mcp-setup에 위임 (B′) |
| "Wiki는 글로벌/로컬 별도 메커니즘이 필요" | Q2 wiki 구조 | 해결: OMC wiki 스킬에서는 "디렉토리 위치 = scope". 2-Tier는 단지 두 위치. |
| "문서↔config 자동 sync 필수" | Contrarian R4 | 수정: 1차 iteration은 수동 규율 + audit, 자동화는 장기 목표로만 |
| "문서는 implementation 후" | R4 pivot | **역전** — Doc audit이 Phase 0, 구현에 선행 |

## Technical Context (brownfield)

### 기존 DATAFACTORY 자산

- `docker/` — `docker-compose.yml` (streaming/headless/ros2 profile), `Dockerfile.ros2` (rosbridge), `entrypoint-mcp.sh`, `enable_mcp.py`, `isaacsim.streaming.mcp.kit`.
- `.mcp.json` — `isaac-sim` (uv run isaac_mcp/server.py, 포트 8766), `ros-mcp` (uvx ros-mcp, 포트 9090).
- `.memory/` — 5개 lesson 파일 (environment, isaac_sim, docker, mcp, tmux_wezterm) + `MEMORY.md` 인덱스.
- `.claude/settings.local.json` — 100+ allowlist 항목, SessionStart/PostCompact 훅 (AGENTS.md + MEMORY.md 로드).
- `.omc/` — project-memory.json, state/, sessions/.
- `AGENTS.md`, `ENVIRONMENT_SETUP.md`, `QUICKSTART.md`, `robot-dev-omc-setup-guide.md` (12 섹션).
- `isaacsim-webrtc-streaming-client-1.0.6-linux-x64.AppImage`.

### 글로벌 OMC (~/.claude/)

- `CLAUDE.md` (OMC:START/END 마커, 4.13.0).
- `settings.json` — `teammateMode: tmux`, `effortLevel: xhigh`, enabledPlugins (context7/superpowers/skill-creator/omc).
- `.omc-config.json` — defaultExecutionMode=ultrawork, team=3 agents (claude provider).
- `hud/omc-hud.mjs`.
- `omc` CLI v4.13.0 글로벌.

### 하드웨어 / OS

- GPU: RTX 5060 (8GB VRAM, CUDA sm_120 Blackwell). iray 경고 무시.
- RAM: 16GB. CPU: i5-14400F.
- Storage: ~80GB 여유.
- Ubuntu Linux 6.8, X11, DISPLAY=:0, IBus, wezterm use_ime=true.

## Ontology (Key Entities)

| Entity | Type | Fields | Relationships |
|---|---|---|---|
| robot (parent repo) | core domain | `scripts/`, `wiki/`, `AGENTS.md`, `.claude/settings.json` | has many Child Project |
| DATAFACTORY (child) | core domain | docker/, .mcp.json, wiki/, V&V execution Phase 2-5 | derived from robot, first child instance |
| Child Project | supporting | scaffolded via bootstrap-child.sh, independent git repo | extends robot structure |
| MCP server | external system | isaac-sim (8766), ros-mcp (9090), future docker | isolated per child via `.mcp.json` |
| OMC Skill | supporting | deepinit, mcp-setup, team, wiki, verify | invoked in setup workflow |
| AGENTS.md | supporting | hierarchical (parent thin, child thick) | generated/maintained via deepinit |
| Wiki (project-local) | supporting | renamed from `.memory/`, at `<child>/wiki/` | scoped to one child |
| Wiki (global) | supporting | at `~/robot/wiki/`, cross-child KB | shared across all children |
| tmux dev-session | supporting | per-child window, hosts Claude Code | uses teammateMode=tmux, one cwd per window |

## Ontology Convergence

| Round | Entity Count | New | Changed | Stable | Stability Ratio |
|---|---|---|---|---|---|
| 1 | 9 | 9 | – | – | N/A |
| 2 | 9 | 0 | 0 | 9 | 100% |
| 3 | 9 | 0 | 0 | 9 | 100% |
| 4 | 9 | 0 | 0 | 9 | 100% |
| 5 | 9 | 0 | 0 | 9 | 100% |
| 6 | 9 | 0 | 0 | 9 | 100% |

5라운드 연속 100% stable → 도메인 모델 완전 수렴.

## Interview Transcript

<details>
<summary>Full Q&A (4 rounds)</summary>

### Round 1 — Targeting: Success Criteria (0.20)
**Q:** ~/robot/ 세팅이 '완료됐다'고 말하려면, 다음 중 어느 검증이 반드시 통과해야 하나요? (A 1-커맨드 스캐폴드 / B DATAFACTORY 재정렬 / C OMC 워크플로우 검증 / D 문서만 완료)
**A:** A + B + C + 문서화도 필요. `.memory/` 처리 관련 OMC-native wiki 조직 방법 질문.
**Ambiguity:** 51% → 34% (Goal 0.60→0.70, Constraints 0.40 유지, Criteria 0.20→0.75, Context 0.85 유지)

### Round 2 — Targeting: Constraint Clarity (0.40)
**Q:** Wiki/Memory 아키텍처 — 네 가지 중 어느 방향? (A 2-Tier+rename / B 2-Tier+공존 / C Global-only / D Project-only)
**A:** A. 2-Tier + rename (추천안 채택).
**Ambiguity:** 34% → 28.3%

### Round 3 — Targeting: Constraint Clarity (0.55)
**Q:** 첫 이터레이션 scope decomposition? (A 최소 MVP / C Hybrid / B Full framework / D Dual track)
**A:** C + 문서화 1급 산출물(skills/MCP/wezterm/tmux 세팅 md 고도화), QUICKSTART 유지, MCP/skill 변경 ↔ 문서 동기화 규율 필요.
**Ambiguity:** 28.3% → 20.55%

### Round 4 — 🔥 CONTRARIAN MODE — Targeting: Constraint Clarity (0.72)
**Q:** 문서↔MCP/skill 동기화 — 어느 레벨까지? (B CI/hook 경고 / C 수동 + 체크리스트 / A Doc-driven config / D Sync 불필요)
**A:** 장기 이상 = B, 하지만 **즉시 우선: "문서화 상태 확인부터"** — Isaac Sim 설치, 스트리밍 클라이언트, Docker MCP 연결 pain-points 반영 여부 먼저 audit.
**Ambiguity:** 20.55% → **14%** ✅

### Round 5 — Targeting: 사용자 선택 (threshold 이미 통과, 사용자 "더 정제" 요청)
**Q:** 남은 gap 4개 (i 스킬/MCP 인벤토리 / ii DATAFACTORY 이관 방식 / iii 시간예산 / iv Doc audit 주체) 중 어디부터?
**A:** (i) 스킬/MCP 인벤토리. 추가 제안: **OMC 산출물 경로도 프로젝트 폴더 안에서** — per-repo scoping 원칙 확인.
**Ambiguity:** 14% → 15.2% (신규 gap 열림)

### Round 6 — Targeting: Constraint Clarity (OMC artifact path + skill/MCP inventory)
**Q:** Skill/MCP 인벤토리 첫 이터레이션 범위? (A 최소 / B +Docker MCP / C +WebSearch / D +custom robot skills)
**A:** A. 최소 세트. (YAGNI — 글로벌 enabled 플러그인만, 새 skill/MCP 추가 없음)
**Ambiguity:** 15.2% → **11.25%** ✅
</details>
