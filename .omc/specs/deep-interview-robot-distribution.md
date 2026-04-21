# Deep Interview Spec: robot 레포를 공유 가능한 로봇 dev environment distribution으로

## Metadata
- Interview ID: robot-distribution-20260421
- Rounds: 6
- Final Ambiguity Score: 13.75%
- Type: brownfield
- Generated: 2026-04-21
- Threshold: 15% (deep mode)
- Status: PASSED

## Clarity Breakdown
| Dimension | Score | Weight | Weighted |
|---|---|---|---|
| Goal Clarity | 0.90 | 0.35 | 0.315 |
| Constraint Clarity | 0.85 | 0.25 | 0.213 |
| Success Criteria | 0.80 | 0.25 | 0.200 |
| Context Clarity | 0.90 | 0.15 | 0.135 |
| **Total Clarity** | | | **0.863** |
| **Ambiguity** | | | **0.138** |

## Goal

`~/robot/` 레포를 **공유 가능한 로봇 개발 환경 distribution**으로 발전시킨다. 타인이 `git clone --recurse-submodules` + `./scripts/install.sh` 하나로 다음을 재현할 수 있어야 한다:

1. 호스트 OS 레벨 (Ubuntu 22.04) 의존성 설치 — Docker, NVIDIA Container Toolkit, jq/xclip/xsel/libfuse2/tmux 3.2+
2. 사용자 dotfiles — wezterm/tmux/X11(IBus) 설정 심링크
3. CLI 툴체인 — Node.js 20+, Claude Code CLI, OMC 플러그인 + `omc` npm, robotics-agent-skills
4. Claude 환경 marker 주입 — `~/.claude/CLAUDE.md`에 robot 전용 섹션, `settings.json` 훅 병합, commands 및 agents
5. Vendored isaac-sim-mcp (4.5.0 API + mcp 1.27 패치 포함)
6. Child 프로젝트 템플릿 — Isaac Sim + ROS2 Docker compose, `.mcp.json` seed, `AGENTS.md` scaffold

성공의 최종 기준: `./scripts/doctor.sh` 전 layer green.

## Constraints

### 확정 제약
- **OS**: Ubuntu 22.04 strict. 24.04/Debian/기타 배포판은 untested. Windows 사용자는 docs/WINDOWS_GUIDE.md에서 WSL2 포인터만 제공.
- **GPU**: NVIDIA 계열 + dynamic detection. install.sh는 tier를 강제하지 않음. doctor.sh가 `nvidia-smi`로 compute capability + VRAM 확인, sm_86/8GB 미달 시 경고만. iray 미지원 경고는 generic 처리.
- **Secrets**: `.env.local` (gitignored) 1차 + shell env `--env-from-shell` 2차. 대화형 사용자 + CI/자동화 양쪽 지원. `.env.template`이 레퍼런스. 지원 변수: 최소 `NGC_API_KEY`.
- **Dotfiles conflict**: backup → symlink 기본 정책. 기존 파일을 `<file>.pre-robot.<timestamp>.bak`로 이동 후 repo 파일로 심링크. `merge-dotfiles.sh`가 대화형 수동 병합 보조 제공.
- **idempotency**: install.sh 재실행 안전. 모든 단계가 "already-done" 감지 후 skip.
- **sudo**: 상단에서 `sudo -v` 한 번, timestamp 유지(`sudo -n true` 주기 연장). apt/docker/NVIDIA toolkit만 sudo 필요.
- **Audience**: 단기 option 2 (랩/팀 private), 장기 option 3 (공개). 처음부터 public-ready 수준으로 secret 분리 + 파라미터화.
- **Distribution boundary**: Conservative — vendor/isaac-sim-mcp submodule + ~/.claude marker-injection + datafactory 제외 (개인 자산).

### Non-goals
- GitHub Actions CI (NVIDIA runner 비용 큼, 스코프 제외. 장기 관찰 항목).
- Windows/macOS 네이티브 지원.
- `~/.claude/` 전체 mirror (사용자 소유권 보존).
- `datafactory`의 distribution 편입 (개인 자산 유지).
- NVIDIA 없는 환경의 CPU fallback.
- 1Password CLI 등 외부 secret manager 의존.

## Acceptance Criteria

### AC-0: 사전조건
- [ ] Ubuntu 22.04 (`lsb_release -c` → jammy) fresh or pre-existing. NVIDIA GPU 탑재.
- [ ] `git clone --recurse-submodules` 성공 (vendor/isaac-sim-mcp + external/robotics-agent-skills).

### AC-1: install.sh 실행
- [ ] `./scripts/install.sh --dry-run`: 각 단계 의도 출력, 쓰기 없음.
- [ ] `./scripts/install.sh --step=host|dotfiles|cli|claude|vendor|child`: 단일 레이어만 실행 가능.
- [ ] `./scripts/install.sh`: 모든 레이어 순차 실행. sudo 한 번만 요청.
- [ ] 재실행 시 모든 단계 "SKIP (already done)" 로그. 파일 손상 0.
- [ ] dotfiles 충돌 시 `.pre-robot.<ts>.bak` 백업 + 심링크. 기존 파일 손실 0.
- [ ] `.env.local` 부재 시 interactive prompt, shell에 `NGC_API_KEY` 있으면 자동 사용.

### AC-2: doctor.sh 검증 (성공 게이트)
모든 체크 green이면 success. 개별 체크:
- [ ] **host**: `docker --version`, `nvidia-smi` (compute capability ≥ sm_86, VRAM ≥ 8GB — 미달은 WARNING), `jq --version`, `xclip -version`, `libfuse2 dpkg` installed, `tmux -V ≥ 3.2`.
- [ ] **dotfiles**: `~/.config/wezterm/wezterm.lua`, `~/.tmux.conf`, `~/.xprofile` 모두 `~/robot/dotfiles/` symlink (readlink 검증).
- [ ] **cli**: `node --version ≥ 20`, `claude --version`, `omc --version`, `/plugin list | grep oh-my-claudecode`.
- [ ] **claude**: `~/.claude/CLAUDE.md`에 `# OMC:START ... OMC:END` 마커 존재, `~/.claude/settings.json`에 `teammateMode: tmux` + `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, `~/.claude/commands/save-memory.md` 존재.
- [ ] **vendor**: `~/robot/vendor/isaac-sim-mcp/` submodule 체크아웃, `isaac_mcp/server.py`에서 `FastMCP(name=...)` 패치 확인 (1.27 호환), `extension.py`에서 `from isaacsim.core.api import World` 4.5 API 확인.
- [ ] **secrets**: `.env.local` 존재 또는 shell env `NGC_API_KEY` 세팅, `docker login nvcr.io` 가능 (token echo 안 함, credential helper만 확인).
- [ ] **templates**: `~/robot/templates/docker/` 전체 파일 존재 + 무결성.

### AC-3: bootstrap-child.sh 재현 (end-to-end)
- [ ] `bootstrap-child.sh newchild --profile=isaac+ros2` 실행 → `~/robot/newchild/` 생성.
- [ ] 생성된 child에서 `docker compose --profile streaming up -d` 성공.
- [ ] `container_name`이 `newchild_isaac_sim`으로 파라미터 치환됨 (datafactory 하드코드 재발 방지).
- [ ] child `.mcp.json`의 `../vendor/isaac-sim-mcp` 경로 유효.
- [ ] Claude Code 세션 시작 → isaac-sim MCP `get_scene_info` 성공 + rosbridge 9090 `connect_to_robot` 성공.

### AC-4: distribution-portability
- [ ] `~/robot/` 내 파일을 `rg -l "(datafactory|Desktop/Project|hasemu1211|/home/codelab)" | grep -v '.git\|wiki\|docs'` → 0 히트 (코드·스크립트·템플릿 스코프).
- [ ] `.mcp.json.tmpl`, `docker-compose.yml` 등 모든 템플릿 변수가 `${VAR}` 형식, 하드코드 경로 없음.
- [ ] Fresh Ubuntu 22.04 VM에서 (최소 수동 1회) install.sh + doctor.sh PASS 시연 스크린샷/로그를 `docs/VERIFIED.md`에 기록.

### AC-5: 문서 완비
- [ ] `README.md`: 3분 설치 quickstart + 전체 워크플로우 flowchart.
- [ ] `docs/INSTALL.md`: install.sh 각 단계 상세 + 트러블슈팅.
- [ ] `docs/HOST_PREREQUISITES.md`: datafactory `ENVIRONMENT_SETUP.md`에서 host 레벨 부분만 추출.
- [ ] `docs/WINDOWS_GUIDE.md`: WSL2 포인터 + GPU passthrough 주의사항 (스코프 밖임을 명시).
- [ ] `docs/MERGE_DOTFILES.md`: 기존 dotfiles와 수동 병합 절차 (merge-dotfiles.sh 호출 + 수동 diff).

## Assumptions Exposed & Resolved

| Assumption | Challenge | Resolution |
|---|---|---|
| "datafactory 자산을 그대로 복사해도 됨" | 환경변수 유착 (container_name, compose project name, GPU SM, host paths) | 3축(재사용/파라미터화/.env 분리)으로 명시적 분류 후 승격 |
| "parent repo는 template-only" | 사용자 비전: 공유 가능한 distribution | 4 레이어(host/dotfiles/CLI+skills/Claude+vendor) + child 템플릿 5번째 레이어 |
| "OMC 글로벌 설정은 repo 밖 자산이다" | 재현성 요구 | marker-section 주입 + settings snippet merge. 완전 mirror 대신 사용자 소유권 보존 |
| "isaac-sim-mcp는 외부 자산" | 패치 필수 (4.5 API + mcp 1.27) → 공개 사용자 수동 패치 불가 | `vendor/isaac-sim-mcp/` submodule fork에 패치 commit |
| "GPU는 RTX 5060 고정" (Contrarian R4) | 공개 진입 장벽 | NVIDIA any + dynamic detect. iray 경고 generic 처리 |
| "최대주의 distribution" (Simplifier R6) | ~/.claude 전체 mirror → 사용자 자산 덮어쓰기 위험 | Conservative boundary: marker-injection만 |
| "install.sh는 unattended 1-shot" | 사용자 기존 dotfiles 손실 위험 | backup → symlink + merge-dotfiles.sh 보조 |
| "NGC는 사용자가 알아서" | CI/자동화 시 삽입점 부재 | `.env.local` 1차 + `--env-from-shell` 2차 |

## Technical Context

### 기존 parent 자산 (보존/확장)
- `scripts/bootstrap-child.sh`, `scripts/promote.sh` — 유지. bootstrap은 `--profile=isaac+ros2` 플래그 + 템플릿 치환 추가.
- `wiki/` 전체 + 2-Tier SessionStart/PostCompact 훅 — 유지. `settings.json`의 훅 body는 `claude/settings-seed.json`으로 복제.
- `.claude/settings.json` (parent 자신) — 유지, marker로 감쌈.
- `.omc/` — 유지 (tracked: specs/plans/research; gitignored: state/sessions/logs/notepad).
- `external/robotics-agent-skills/` — `git submodule` 정식 전환.

### datafactory에서 추출 (3축 분류)

#### (a) 그대로 재사용 가능
- `docker/entrypoint-mcp.sh` → `templates/docker/entrypoint-mcp.sh`
- `docker/enable_mcp.py` → `templates/docker/enable_mcp.py`
- `docker/isaacsim.streaming.mcp.kit` → `templates/docker/isaacsim.streaming.mcp.kit`
- `docker/Dockerfile.ros2` → `templates/docker/Dockerfile.ros2`
- isaac-sim-mcp 4.5 API + mcp 1.27 패치 → `vendor/isaac-sim-mcp/` 커밋
- `scripts/clean_storage.sh` → `templates/scripts/clean_storage.sh`
- `.claude/commands/save-memory.md` → `claude/commands/save-memory.md`

#### (b) 파라미터화 후 템플릿 승격
- `docker/docker-compose.yml`:
  - `container_name: datafactory_*` → `container_name: ${PROJECT_NAME}_*` (lesson h 재발 방지)
  - `../../isaac-sim-mcp` → `${ROBOT_ROOT}/vendor/isaac-sim-mcp`
  - `ROS_DISTRO=humble` → `.env` 기본값 + override 가능
  - `RMW_IMPLEMENTATION` → `.env`
- `.mcp.json` → `.mcp.json.tmpl` with `${ROBOT_ROOT}/vendor/isaac-sim-mcp`
- `docker/.env` → `templates/docker/.env.template` (`COMPOSE_PROJECT_NAME`, `ROS_DOMAIN_ID`, `DATA_DIR` 등)
- `AGENTS.md` — 현재 bootstrap이 찍는 stub 두께 2배로 확장 (MCP 섹션, Phase 섹션 자리표시자 포함)

#### (c) .env.local / gitignore로 분리
- `NGC_API_KEY`
- `GPU_SM_LEVEL` (옵션 — doctor.sh가 자동 감지, override 가능)
- `CLAUDE_API_KEY` (Claude Code CLI가 이미 관리하므로 repo 스코프 밖)

### 새로 작성 필요
- `scripts/install.sh` — 오케스트레이터 (host/dotfiles/cli/claude/vendor/child 레이어).
- `scripts/doctor.sh` — 전 레이어 검증 (AC-2 각 체크 구현).
- `scripts/merge-dotfiles.sh` — 대화형 병합 보조.
- `dotfiles/` — `~/.config/wezterm/wezterm.lua`, `~/.tmux.conf`, `~/.xprofile`을 재현 가능한 형태로 커밋.
- `claude/CLAUDE-marker.md`, `claude/settings-seed.json`, `claude/commands/*.md`.
- `docs/INSTALL.md`, `docs/HOST_PREREQUISITES.md`, `docs/WINDOWS_GUIDE.md`, `docs/MERGE_DOTFILES.md`, `docs/VERIFIED.md`.

## Ontology (Key Entities)

| Entity | Type | Fields | Relationships |
|---|---|---|---|
| robot-repo | core | name, submodules, layers | has-many child-project, has layers |
| child-project | core | docker-stack, mcp-config, env-vars | child-of robot-repo, uses vendored-mcp |
| install-script | core | flags(`--dry-run`,`--step`,`--yes`), idempotent | orchestrates layers |
| doctor-script | core | checks[], pass-criteria[] | validates install-script output |
| audience-user | external | os-version=Ubuntu22.04, gpu, ngc-token, existing-dotfiles | clones robot-repo, runs install-script |
| host-environment | supporting | apt-deps, nvidia-toolkit, docker, tmux, x11 | hosted-by audience-user |
| claude-environment | supporting | OMC-plugin, skills, agents, CLAUDE.md-marker | integrated-by install-script (marker-injection) |
| docker-stack | supporting | compose-profile, container-name, ports | templated-in templates/docker, instantiated-per child-project |
| dotfiles | supporting | paths, backup-policy | symlinked-by install-script, merge-helper-assisted |
| vendored-mcp | supporting | branch, patches (4.5 API + mcp 1.27) | submodule-of robot-repo, used-by docker-stack |
| bootstrap-child-script | supporting | template-substitution, `--profile=isaac+ros2` | generates child-project from templates |
| merge-helper | supporting | interactive, diff-based | assists dotfiles manual merge |
| datafactory | external | symlink(legacy), not in distribution | personal asset of current user only |

## Ontology Convergence

| Round | Entity Count | New | Changed | Stable | Stability Ratio |
|---|---|---|---|---|---|
| 1 | 10 | 10 | - | - | N/A |
| 2 | 11 | 1 (doctor-script) | 0 | 10 | 91% |
| 3 | 12 | 1 (merge-helper) | 0 | 11 | 92% |
| 4 | 12 | 0 | 0 | 12 | 100% |
| 5 | 12 | 0 | 0 | 12 | 100% |
| 6 | 13 | 1 (datafactory ext 강등) | 0 | 12 | 100% |

모델 수렴. 4라운드 연속 stability 100%.

## Interview Transcript
<details>
<summary>Full Q&A (6 rounds)</summary>

### Round 1 — Primary audience
**Q:** 이 distribution의 주 사용자는 누구인가요?
**A:** "2지만 3을 지향 다만 환경은 무조건 우분투 22.04를 가정 혹시모를 window 사용자를 위한 안내"
**Ambiguity after:** 56.5% (Goal 0.65, Constraints 0.35, Criteria 0.15, Context 0.55)

### Round 2 — Success test
**Q:** "install.sh가 성공했다"는 것을 어떻게 검증하고 싶으세요?
**A:** "Idempotent + doctor.sh green (Recommended)"
**Ambiguity after:** 36.75% (Goal 0.75, Constraints 0.45, Criteria 0.70, Context 0.55)

### Round 3 — Dotfiles policy
**Q:** 기존 사용자 dotfiles가 이미 있을 때 install.sh는 어떻게 처리?
**A:** "Backup → symlink (Recommended) 로 우선하고 수동 병합 절차도 진행할수있게 안내든 뭐든 절차가있으면 좋을거같아"
**Ambiguity after:** 31.4% (Goal 0.78, Constraints 0.60, Criteria 0.72, Context 0.55)

### Round 4 — GPU scope (Contrarian)
**Q:** GPU 지원 범위를 어떻게 잡을까요? [Contrarian: RTX 5060만 검증 가정이 틀렸을 때 재작업?]
**A:** "NVIDIA any + dynamic detect (Recommended)"
**Ambiguity after:** 27.05% (Goal 0.82, Constraints 0.72, Criteria 0.72, Context 0.55)

### Round 5 — Secrets flow
**Q:** NGC API KEY·기타 비밀 정보는 어떻게 흘러가야?
**A:** "`.env.local` + `--env-from-shell` 이중 지원 (Recommended)"
**Ambiguity after:** 22% (Goal 0.85, Constraints 0.85, Criteria 0.75, Context 0.55)

### Round 6 — Distribution boundary (Simplifier)
**Q:** robot 레포가 어디까지 '안으로 포함'? [Simplifier: 최소로 충분한 경계?]
**A:** "Conservative — vendor/isaac-mcp만 (Recommended)" + "필요한것들꼼곰히 알맞게 가져와야해 일단 너의 판단을 믿을게"
**Ambiguity after:** 13.75% (Goal 0.90, Constraints 0.85, Criteria 0.80, Context 0.90) — **THRESHOLD PASSED**

</details>

## Next Stage

이 spec을 **3-Stage Pipeline (Recommended)** 으로 실행:
1. 이 spec → `/oh-my-claudecode:omc-plan --consensus --direct`: Planner/Architect/Critic 합의로 구현 계획 생성 (`~/robot/.omc/plans/` 출력)
2. 계획 → `/oh-my-claudecode:autopilot`: Phase 2 Execution (Ralph + Ultrawork)부터 시작

또는 개별 레이어를 단계별로 실행 가능 — 본인 선호에 따라 선택.
