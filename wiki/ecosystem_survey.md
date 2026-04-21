# Claude Code 생태계 Survey (2026-04-20)

> 5계층 survey — 로봇 parent repo 관점에서 enabled 플러그인, 외부 생태계, 공식 마켓플레이스, 갭, MCP 후보.
> 검증된 2026-04 live 데이터 기반. 세부 갭 분석은 `.omc/research/skill-gap-analysis-20260420.md` 참조.

## T1 — 설치된 플러그인 스킬 카탈로그

### `oh-my-claudecode` v4.13.0 (39 skills, 상위 관련순)

| 스킬 | 카테고리 | 로봇 repo 적합도 | 비고 |
|---|---|---|---|
| `mcp-setup` | MCP 구성 | ★★★ | Isaac/ROS2/Docker MCP 격리 핵심 |
| `deepinit` | 초기화 | ★★★ | child의 계층적 AGENTS.md 생성 |
| `ralplan` / `plan` | 계획 | ★★★ | Planner/Architect/Critic 합의 |
| `deep-interview` | 요구사항 | ★★★ | ambiguity 수학 게이팅 (지난 세션 11.25%) |
| `autopilot` | 실행 | ★★★ | Phase 0–5 end-to-end |
| `ralph` | 실행 루프 | ★★ | acceptance-criteria 달성까지 |
| `ultrawork` | 병렬 | ★★ | 독립 태스크 고쓰루풋 |
| `team` | 병렬 | ★★ | tmux teammate (MCP 격리 우회) |
| `verify` | 검증 | ★★★ | 완료 주장 전 필수 |
| `ultraqa` | QA | ★★ | test-verify-fix 루프 |
| `trace` / `deep-dive` | 디버깅 | ★★★ | sim/hardware 원인 추적 |
| `debug` | 디버깅 | ★★ | OMC 세션/repo 진단 |
| `remember` | 지식 | ★★★ | 승격 판단 워크플로우 |
| `learner` / `skillify` | 메타 | ★★ | 반복 패턴 → 스킬 증류 |
| `wiki` | 지식 | ★★★ | scope = cwd/wiki/ (이미 사용 중) |
| `external-context` | 조사 | ★★★ | 오늘 이 survey처럼 병렬 문서 조사 |
| `sciomc` | 조사 | ★★ | 병렬 scientist 에이전트 |
| `ccg` | 멀티모델 | ★ | Claude+Codex+Gemini 동시 |
| `omc-teams` | 병렬 | ★ | tmux 기반 CLI 팀 |
| `release` | 릴리즈 | ★ | 4.13.0부터 generic repo-aware |
| `cancel` | 운영 | ★★★ | 모든 autopilot/ralph 중단 |
| `omc-setup` / `omc-doctor` | 운영 | ★ | 설치/진단 |
| `ai-slop-cleaner` | 품질 | ★★ | LLM 생성 slop 정리 |
| `self-improve` | 품질 | ★ | 진화적 개선 엔진 |
| `visual-verdict` | QA | ★★ | 스크린샷 비교 (Isaac 렌더) |
| `autoresearch` | 조사 | ★★ | self-eval 단일 미션 루프 |
| `project-session-manager` | 워크플로우 | ★★ | worktree-first 이슈/PR |
| `configure-notifications` | 운영 | ★ | Telegram/Discord |
| `hud` | UI | — | HUD 설정 |
| `ask` | 라우팅 | ★ | 어드바이저 라우팅 |
| `writer-memory` | — | — | 소설 작법 (무관) |
| `skill` | 관리 | ★★ | 로컬 스킬 CRUD |
| `omc-reference` | 참조 | ★★★ | OMC 카탈로그 (자동 로드) |

### `superpowers` (17 skills — deprecated alias 제외 13개 활성)

| 스킬 | OMC 중복? | 유니크 가치 |
|---|---|---|
| `test-driven-development` | **없음** | 🔵 **유일한 TDD 스킬** |
| `receiving-code-review` | **없음** | 🔵 리뷰 수신 프로토콜 |
| `finishing-a-development-branch` | **없음** | 🔵 브랜치 종료 체크리스트 |
| `brainstorming` | `deep-interview`가 더 수학적 | 🟡 softer 대안 |
| `systematic-debugging` | `debug` + `trace`와 겹침 | 🟡 방식 차이 |
| `verification-before-completion` | `verify`와 겹침 | 🟡 OMC가 더 구조적 |
| `dispatching-parallel-agents` | `ultrawork`/`ccg`/`team` | 🟠 중복 |
| `subagent-driven-development` | `team` | 🟠 중복 |
| `writing-plans` | `plan`/`ralplan` | 🟠 중복 |
| `executing-plans` | `autopilot` | 🟠 중복 |
| `requesting-code-review` | `code-reviewer` agent로 대응 | 🟠 중복 |
| `using-git-worktrees` | `project-session-manager` | 🟠 중복 |
| `using-superpowers` | — | 🟢 메타 (시작 게이트) |

**Deprecated aliases**: `brainstorm`, `write-plan`, `execute-plan` (현재 `omc_workflows.md` 8번째 줄이 deprecated `brainstorm`를 참조 중 → 이번 turn에 업데이트).

### `skill-creator`

- 단일 스킬: 새 스킬 생성/편집/평가. 커스텀 `/robot:*` 스킬 작성 시 필수.

### `context7` (MCP 플러그인)

- 두 개의 MCP 도구: `resolve-library-id`, `query-docs`.
- Isaac Sim 4.5 / ROS2 humble 커버리지는 `resolve-library-id` 호출로 확인 필요.
- 학습 데이터 대비 신선도 보장용.

---

## T2 — 생태계 탐색 (2026-04 live)

### Claude Code + 로봇공학

- **`robotmcp/ros-mcp-server`** — Claude/GPT ↔ ROS/ROS2 자연어 제어. rosbridge WebSocket 기반. Humble/Jazzy/ROS1 전부 지원. **현재 우리 스택과 동일한 패턴** — 따로 도입할 필요 없음, 레퍼런스 구현으로 참고.
- **Robosynx + Isaac Monitor** — 2026-04 공개된 Isaac Sim + ROS2 full-stack 플랫폼. MCP 내장, GPU/훈련 로그 자연어 조회. 상용 성향, 영감용.
- **NVIDIA Developer Forum 튜토리얼** — "Setting up MCP server using Claude on a Linux system for Isaac Sim" 스레드 활발. 우리 wiki의 `mcp_lessons.md` 패치 경험과 교차검증 가능.
- **`hijimasa/isaac-ros2-control-sample`** — Isaac Sim + ros2_control 자동 센서 생성. datafactory 후속 child에 reusable.

### Claude Code 플러그인 마켓플레이스

- **공식**: `anthropics/claude-plugins-official` (GitHub) + `claude.com/plugins` (웹 카탈로그). 현재 DevTools/CI/보안 중심. **robotics 카테고리 부재** → 갭.
- **커뮤니티 카탈로그**: `claudemarketplaces.com`, `aitmpl.com/plugins`, `mcpservers.org` (MCP 서버 인덱스).

---

## T3 — 공식/업스트림 릴리즈

| 플러그인 | 설치됨 | 최신 확인 | 비고 |
|---|---|---|---|
| `oh-my-claudecode` | 4.13.0 | 4.12.0 article 2026-04-02; 4.13.0 release skill refactor | **최신** |
| `superpowers` | (확인 필요) | `obra/superpowers` 활성 | 유니크 스킬 4개 |
| `skill-creator` | 1 skill | 커뮤니티 | — |
| `context7` | MCP | `upstash/context7-mcp` 주간 릴리즈 | 활성 |

`oh-my-claudecode` 4.12.0 → 4.13.0 diff 핵심: `release` 스킬이 generic repo-aware 어시스턴트로 rewrite, autopilot 안정성, keyword detection 정확도, HUD 개선.

---

## T4 — 갭 분석 (요약; 전체는 `.omc/research/skill-gap-analysis-20260420.md`)

**즉시 갭 (adopt now)**:
1. **Docker MCP Toolkit** — rosbridge 컨테이너 + datafactory Compose 관리. 현재 Bash만으로 가능하지만 natural-language 표면이 생산성↑.
2. **Exa MCP** — 이번 survey 같은 ecosystem 조사에서 built-in WebSearch보다 semantic depth 우위. 자유 티어 1k/mo.
3. **Context7 resolve-library-id 활용 루틴** — Isaac Sim 4.5 / ROS2 humble API 호출 시 기본 실행. 교훈은 이미 `mcp_lessons.md`에 있음.

**비어있는 영역 (자체 구축)**:
- ROS2/Isaac 전용 OMC 스킬 없음 → `skill-creator`로 `/robot:*` 증류.
- Gazebo/MoveIt/PyBullet MCP 프로덕션급 없음 → 필요 시 우리가 최초 구현 포지션.

---

## T5 — MCP 후보 shortlist

### Tier-1 — 지금 도입

- **Docker MCP Toolkit** — `/plugin install docker-mcp-toolkit@docker` (Docker Desktop 4.62+). Apache 2.0. rosbridge 컨테이너 관리에 즉시 유용.
- **filesystem-mcp** (reference MCP) — per-child `.mcp.json`에 scoped path로 추가. ros2 bag / URDF / 데이터셋 접근.

### Tier-2 — 트라이얼

- **Exa MCP** — `/plugin marketplace add exa-labs/exa-mcp-server && /plugin install exa-mcp-server`. EXA_API_KEY 필요. MIT. ecosystem survey, arXiv/repo 발견에 특화.

### Watch

- **Tavily MCP** — RAG 파이프라인이 생기면.
- **Brave Search MCP** — Exa 쿼터 고갈 시 fallback.
- **ROS2 direct-rclpy MCP** — rosbridge 레이턴시 병목 시.
- **Kubernetes MCP** — child가 k8s 배포하면.

### Skip

- **Perplexity MCP** — canonical 구현 없음.
- **Gazebo/MoveIt/PyBullet MCP** — 존재 안 함. 필요 시 자체 구현.
- **git MCP** — Claude Code 내장 Bash/git로 충분.
- **sequential-thinking MCP** — `ralplan`으로 대체.
- **Perplexity/memory MCP** — 우리는 wiki + `.omc/project-memory.json` 사용.

---

## 참고 링크

- https://github.com/Yeachan-Heo/oh-my-claudecode
- https://github.com/exa-labs/exa-mcp-server
- https://github.com/docker/mcp-gateway
- https://github.com/docker/claude-plugins
- https://github.com/robotmcp/ros-mcp-server
- https://github.com/anthropics/claude-plugins-official
- https://claude.com/plugins
- https://claudemarketplaces.com/
- https://forums.developer.nvidia.com/t/setting-up-mcp-server-using-claude-on-a-linux-system-for-isaac-sim/338707
