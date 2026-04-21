# Agent Cookbook — robot distribution (실제 설정된 toolbox)

이 문서는 robot distribution 환경에서 에이전트가 사용할 수 있는 도구, 워크플로우 레시피, 그리고 지켜야 할 주요 관례를 정의합니다.

## 0. Quick Orientation
세션 시작 시 `wiki/INDEX.md` 및 `AGENTS.md`를 통해 이 환경의 전체 구조를 파악하세요. 본 문서는 구체적인 도구 활용법과 에이전트 관점의 "어떻게(How-to)"를 다룹니다.

## 1. Your Installed Toolbox (actual inventory)

### 1.1 MCP 서버 (세션 시작 시 자동 로드)
| MCP | 스코프 | 용도 | 핫키/검증 |
|---|---|---|---|
| plugin:context7 | 플러그인 | SDK/framework 최신 문서 조회 | `resolve-library-id` → `query-docs` |
| plugin:oh-my-claudecode:t | 플러그인 | OMC 오케스트레이션 브리지 | `state_read/write`, `wiki_*`, `notepad_*` |
| omc (CLI) | 시스템 도구 | 제미니가 클로드와 OMC 메모리 공유 | `omc state-read`, `omc wiki-write` |
| github-mcp-server | user scope | 이슈/PR/리뷰 자동화 | `gh` CLI와 병행 사용 |
| isaac-sim (8766) | child project | Isaac Sim 씬 제어 | `get_scene_info` 우선 호출 |
| ros-mcp (9090) | child project | ROS2 토픽/서비스 (rosbridge) | `connect_to_robot` 우선 호출 |

### 1.2 Plugin skills (description-trigger 자동 로드)
| Plugin | 수 | 대표 스킬 |
|---|---|---|
| oh-my-claudecode | 40+ | `autopilot`, `plan`, `ralph`, `deep-interview`, `wiki`, `remember`, `verify` |
| superpowers | 17 | `brainstorming`, `writing-plans`, `executing-plans`, `tdd`, `systematic-debugging` |
| skill-creator | 1 | 새 스킬 작성 가이드 활성화 |
| robotics-agent-skills | 9 | `ros2`, `docker-ros2-development`, `robot-bringup` (external/ submodule) |

### 1.3 CLI 도구 (install.sh cli 레이어에서 자동)
| CLI | 용도 | 세션에서 활용 |
|---|---|---|
| `claude` | Claude Code 진입점 | — |
| `omc` | OMC CLI (4.13+) | `omc ask <provider> ...` |
| `rtk` | Bash 훅 토큰 압축 (투명) | 자동 작동 (의식 불필요) |
| `notebooklm` | NotebookLM 자동화 | 대규모 문서 분석 (`docs/NOTEBOOKLM.md`) |
| `git`, `gh`, `jq`, `tmux`, `docker`, `nvidia-smi` | 표준 도구 | — |

### 1.4 Distribution 스크립트
| Script | 에이전트 호출 가능? | 용도 |
|---|---|---|
| `scripts/install.sh` | **X** (파괴적) | 사용자에게 안내만 수행 |
| `scripts/doctor.sh --json` | ✅ (Read-only) | 환경 검증 시 활용 |
| `scripts/bootstrap-child.sh` | ✅ (Dry-run 권장) | 새 child 프로젝트 생성 |
| `scripts/promote.sh` | ✅ | 지식/문서를 wiki로 승격 |

## 2. Skills by Situation
- 요구사항 모호 → `deep-interview`
- 계획 필요 → `plan --consensus`
- 자율 실행 → `autopilot --plan`
- 수렴 안 되는 루프 → `ralph`
- 지식 승격 → `remember` → `promote.sh`
- ROS2/Isaac 구현 → robotics-agent-skills (자동 트리거)

## 3. End-to-End Recipes

### Recipe A: 새 child 생성 + Isaac Sim 씬 + ROS2 검증
1. `./scripts/bootstrap-child.sh myrobot --profile=isaac+ros2 --dry-run`
2. `./scripts/bootstrap-child.sh myrobot --profile=isaac+ros2`
3. `cd myrobot && docker compose --profile streaming up -d`
4. `claude` → `get_scene_info()` → `execute_script(...)` (Isaac 씬 구성)
5. ROS2 노드 실행 → `connect_to_robot(port=9090)` → 데이터 검증
6. `verify` 스킬로 증거 수집

### Recipe B: GitHub 이슈 해결 워크플로우
1. `github-mcp-server list_issues`로 작업 대상 파악
2. `get_issue` 상세 분석 후 `plan` 수립
3. 코드 수정 및 테스트
4. `create_pull_request`로 기여

## 4. Robot-Specific Conventions (반드시 준수)

- **ROBOT_ROOT** — 절대 경로 하드코드 금지. 항상 `git rev-parse --show-toplevel`로 기준점 확인.
- **Marker-injection** — `~/.claude/CLAUDE.md`는 직접 편집 금지. `install.sh`가 관리하는 `<!-- OMC:ROBOT:START -->` 블록 준수.
- **2-Tier wiki** — `parent`는 global 지식, `child`는 local 지식을 관리. `wiki` 스킬은 현재 디렉토리 기준 작동.
- **rtk 투명성** — Bash 출력 결과가 압축되어 보일 수 있음. 원본이 필요하면 `cat`이나 `grep` 활용.

## 5. Gotchas (에이전트 주의사항)

- **Isaac Sim 4.5 API**: 반드시 `isaacsim.core.api` 사용 (4.2 이전의 `omni.isaac.core` 지양).
- **mcp 1.27**: `FastMCP(name=...)` 사용 권장.
- **dual-path compose 금지**: 반드시 실제 경로에서만 `docker compose` 실행 (심링크 경로 금지).

## 6. Discovery Commands (세션 시작 시 권장)

```bash
# 설치된 MCP 목록 확인
claude mcp list

# 활성 플러그인 확인
jq '.enabledPlugins' ~/.claude/settings.json

# 시스템 상태 체크
~/robot/scripts/doctor.sh --json | jq '.summary'
```

## 7. References
- `wiki/INDEX.md` — 위키 목차
- `docs/INSTALL.md` — 설치 및 레이어 상세
- `docs/NOTEBOOKLM.md` — NotebookLM 활용법
