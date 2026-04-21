# robot — Shareable robot dev environment distribution

> Ubuntu 22.04 + NVIDIA GPU 호스트용 로봇 개발 환경 **distribution**.
> `git clone --recurse-submodules + ./scripts/install.sh` 한 번으로 **OMC + Isaac Sim/ROS2 Docker 스택 + wezterm/tmux dotfiles + vendored isaac-sim-mcp 패치 + robotics CLI skills** 재현.

## 3분 Quickstart

```bash
# 1. clone (submodule 포함)
git clone --recurse-submodules https://github.com/hasemu1211/robot ~/robot
cd ~/robot

# 2. (1회) NGC 토큰 준비 — Isaac Sim 이미지 pull 권한
cp .env.template .env.local && $EDITOR .env.local   # NGC_API_KEY 입력
# 또는 shell env: export NGC_API_KEY=...

# 3. install 실행 (각 레이어: host apt → dotfiles → cli → claude → vendor → child)
./scripts/install.sh                                  # 대화형 (기본)
./scripts/install.sh --dry-run                        # 먼저 무엇이 실행되는지 보기
./scripts/install.sh --step=host                      # 특정 레이어만
./scripts/install.sh --env-from-shell                 # CI/자동화

# 4. 검증
./scripts/doctor.sh                                    # human report
./scripts/doctor.sh --json | jq .summary              # CI-ready

# 5. 새 로봇 프로젝트 child 부트스트랩
./scripts/bootstrap-child.sh myrobot --profile=isaac+ros2
cd myrobot && docker compose --profile streaming up -d
```

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                        ~/robot/ (distribution)                  │
│                                                                 │
│  Layer 0 (host)      apt + Docker + NVIDIA Container Toolkit   │
│  Layer 1 (dotfiles)  dotfiles/{wezterm.lua,tmux.conf,xprofile}│
│  Layer 2 (cli)       Node20+, claude CLI, OMC, omc npm, rtk   │
│  Layer 3 (claude)    claude/CLAUDE-marker.md (→ ~/.claude)    │
│                      claude/settings-seed.json (additive merge)│
│                      claude/commands/save-memory.md           │
│  Layer 4 (vendor)    vendor/isaac-sim-mcp (submodule, patched)│
│                      external/robotics-agent-skills (submod.) │
│  Layer 5 (templates) child scaffold — bootstrap-child.sh 사용 │
│                      templates/docker/{compose,Dockerfile.ros2,│
│                                        entrypoint-mcp.sh,...}  │
│                      templates/.mcp.json.tmpl                 │
│                      templates/AGENTS.md.tmpl                 │
└─────────────────────────────────────────────────────────────────┘
                             │
           bootstrap-child   ▼
   ┌─────────────────────────────────────────┐
   │  ~/robot/<child>/  (isaac+ros2 profile) │
   │    docker/{compose,...}                 │
   │    .mcp.json (isaac-sim + ros-mcp)      │
   │    AGENTS.md                            │
   │    wiki/ + .claude/ + .omc/             │
   └─────────────────────────────────────────┘
```

**3-Tier 지식 흐름** (2-Tier wiki):

- **Global** `~/robot/wiki/` — 모든 child 공유 교훈 (Isaac Sim API, ROS2 bridge, MCP, OMC)
- **Local** `~/robot/<child>/wiki/` — child 고유 교훈
- SessionStart/PostCompact 훅이 parent + local 자동 주입 (`.claude/settings.json`)

## 레포 구조

```
~/robot/
├── scripts/                      # distribution CLI
│   ├── install.sh                # layered, idempotent, resumable
│   ├── doctor.sh                 # --json + --layer= per-check verification
│   ├── merge-dotfiles.sh         # interactive dotfile reconciliation
│   ├── bootstrap-child.sh        # child scaffold (--profile=isaac+ros2|ros2|bare)
│   └── promote.sh                # child wiki → global wiki 승격
├── claude/                       # ~/.claude 주입 소스 (marker-based, additive)
│   ├── CLAUDE-marker.md          # ROBOT 블록 본문
│   ├── settings-seed.json        # 2-Tier hooks + teammateMode
│   └── commands/save-memory.md
├── dotfiles/                     # wezterm/tmux/xprofile (심링크 소스)
├── templates/                    # child 생성용 파라미터화 템플릿
│   ├── docker/                   # compose.yml, Dockerfile.ros2, entrypoint-mcp.sh, ...
│   ├── scripts/clean_storage.sh
│   ├── .mcp.json.tmpl
│   └── AGENTS.md.tmpl
├── vendor/                       # submodule (project-owned fork)
│   └── isaac-sim-mcp/            # 4.5.0 API + mcp 1.27 패치 적용본
├── external/                     # third-party submodule
│   └── robotics-agent-skills/    # arpitg1304/robotics-agent-skills
├── patches/                      # B-7 supply-chain audit (git format-patch)
├── wiki/                         # 🌐 global KB
├── docs/                         # distribution 사용자 문서
│   ├── INSTALL.md
│   ├── HOST_PREREQUISITES.md
│   ├── WINDOWS_GUIDE.md
│   ├── MERGE_DOTFILES.md
│   ├── VERIFIED.md               # doctor 결과 로그 (machine-specific)
│   └── ROBOTICS_SKILLS.md
├── .omc/                         # specs/plans/research (tracked) + state/sessions/logs (gitignored)
├── .env.template                 # secrets 변수 reference (→ .env.local gitignored)
├── README.md                     # 본 파일
├── AGENTS.md                     # parent 네비게이션
└── CLAUDE.md                     # OMC 기본값 (→ ~/.claude/CLAUDE.md 상속)
```

## 환경 요구사항

- **OS**: Ubuntu 22.04 strict (24.04는 `--force-os`로 시도 가능, 미검증)
- **GPU**: NVIDIA (compute capability ≥ sm_86, VRAM ≥ 8GB 권장). Isaac Sim 제외 시 NVIDIA 불필요
- **기타**: Node.js 20+, tmux 3.2+, Docker 24+, jq, xclip, xsel, libfuse2
- **NGC 계정**: `docker login nvcr.io` (Isaac Sim 이미지 pull용)

상세: [`docs/HOST_PREREQUISITES.md`](docs/HOST_PREREQUISITES.md).

## Windows 사용자

네이티브 지원 X. WSL2(Ubuntu 22.04) 권장 — 단, GPU passthrough 주의. [`docs/WINDOWS_GUIDE.md`](docs/WINDOWS_GUIDE.md) 참조.

## 기존 dotfiles와의 통합

install.sh는 기본 `backup → symlink` (기존 파일을 `<file>.pre-robot.<ts>.bak`으로 이동). 수동 병합이 필요하면 `scripts/merge-dotfiles.sh` 대화형. [`docs/MERGE_DOTFILES.md`](docs/MERGE_DOTFILES.md) 참조.

## Children (예시)

**distribution 자체에는 children 포함 안 됨** — 사용자가 `bootstrap-child.sh` 로 자신의 child 생성:

```bash
./scripts/bootstrap-child.sh myrobot --profile=isaac+ros2
# ~/robot/myrobot/ 생성 — docker/ 스택, .mcp.json (isaac-sim + ros-mcp), AGENTS.md 자동
```

각 child는 독립 git repo (또는 심링크)로 유지. 여러 child가 쌓이면 `bootstrap-child.sh` 가 parent `AGENTS.md`의 Children 섹션에 1행씩 append.

## 주요 OMC 워크플로우

| 용도 | 스킬 |
|---|---|
| 새 child 초기 AGENTS.md | `/oh-my-claudecode:deepinit` |
| child MCP 격리 | `/oh-my-claudecode:mcp-setup` |
| 위키 읽기/쓰기 | `/oh-my-claudecode:wiki` (scope = cwd의 `wiki/`) |
| 합의 계획 (Planner/Architect/Critic) | `/oh-my-claudecode:plan --consensus` |
| 자율 실행 | `/oh-my-claudecode:autopilot --plan <path>` |
| child → global 승격 판단 | `/oh-my-claudecode:remember` → `scripts/promote.sh` |

## 기타 도구

- `oh-my-claudecode` — 멀티 에이전트 오케스트레이션
- `superpowers` — TDD, brainstorming, verification-before-completion
- `context7` — 외부 API 문서 조회 (Isaac Sim, ROS2, NumPy 등)
- `rtk` — Claude Code Bash 훅에서 CLI 출력 60-90% 토큰 압축 (`rtk init -g`)

## 설계 문서

- `.omc/specs/deep-interview-robot-distribution.md` — 원본 deep-interview spec (ambiguity 13.75%, 6 rounds)
- `.omc/plans/robot-distribution-plan.md` — consensus-approved 구현 계획 (Architect PASS + Critic APPROVED_WITH_IMPROVEMENTS, iter 2 final)
- `wiki/ecosystem_survey.md` — T1-T5 플러그인/스킬/MCP 카탈로그

## 라이선스

MIT (이 레포). 포함된 `vendor/isaac-sim-mcp/` fork의 라이선스는 원본 upstream 준수.
