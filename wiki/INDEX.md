# Robot Wiki — Global Index

> 모든 robot child 프로젝트가 공유하는 **cross-project** 지식 베이스.
> `~/robot/.claude/settings.json` SessionStart 훅이 이 파일을 자동 로드.
> parent 세션에서는 Project wiki 재주입 생략 (중복 방지).

## 📚 교훈 & 레퍼런스

### Isaac Sim / ROS2 / MCP 스택

- [Isaac Sim API 패턴](isaac_sim_api_patterns.md) — 4.5.0 API 경로, 4.2→4.5 patch, Kit extension 로딩
- [ROS2 Bridge](ros2_bridge.md) — rosbridge Docker 이미지, 포트 9090, DDS 자동 발견
- [MCP 교훈](mcp_lessons.md) — mcp 1.27 호환성 패치, extension 활성화 트릭, user-scope agent hot-load 제약

### OMC 워크플로우 & 생태계

- [OMC 워크플로우](omc_workflows.md) — deepinit/plan/autopilot 파이프라인, 2-Tier wiki, tmux teammate 모드
- [생태계 Survey](ecosystem_survey.md) — T1-T5 플러그인·스킬·MCP 카탈로그 (2026-04)

### 호스트 환경 세팅 (교훈)

- [Docker / compose 교훈](lessons_docker.md) — profiles로 GUI/Headless 분리, container_name 충돌, `network_mode: host` DDS
- [환경 세팅 교훈](lessons_environment.md) — jq/xhost/IBus/한글 입력/Nerd Font
- [tmux + WezTerm 교훈](lessons_tmux_wezterm.md) — xclip, mouse, prefix `\` 바인딩(IBus 회피), OMC 글로벌 설치 상태

## 🧩 Children Status

| Child | 상태 | 비고 |
|---|---|---|
| `datafactory/` (legacy symlink) | Phase 1 완료 (개인 자산, distribution 스코프 외) | `bootstrap-child.sh newchild --profile=isaac+ros2` 으로 새 child 생성 가능 |

향후 새 children 추가 시 이 표에 append. 자식 INDEX 전체 주입은 하지 않음 — 필요 시 `cat ~/robot/<child>/wiki/INDEX.md` 로 직접 조회.

## 🧠 외부 robotics 스킬 (3rd-party submodule)

- 소스: `~/robot/external/robotics-agent-skills` (`arpitg1304/robotics-agent-skills`, submodule 전환 예정)
- 9개 스킬: `ros2`, `docker-ros2-development`, `ros2-web-integration`, `robotics-design-patterns`, `robotics-testing`, `robot-perception`, `robot-bringup`, `robotics-security`, `robotics-software-principles`
- child에 심링크 주입: `docs/ROBOTICS_SKILLS.md` 참조
- Claude Code 진행 시 description trigger로 auto-load (progressive disclosure)

## 🔄 승격 규칙 (Child → Global)

### 분류 체크리스트

| 질문 | Yes → | No → |
|---|---|---|
| 2개 이상 child에 적용 가능한가? | 승격 후보 | child-local 유지 |
| 프로젝트 고유 수치/경로/설정 포함? | child-local 유지 | 승격 후보 |
| 재현 가능한 추상 패턴인가? | 승격 후보 | child-local 유지 |
| 다른 프로젝트에 프라이버시 문제? | 절대 승격 X | — |
| 두 번째 작성 중인가? | 즉시 승격 | 한 번 더 겪으면 재평가 |

3개 이상 Yes → 승격 강력 추천. 1-2개 Yes → borderline, 1 세션 관찰 후 결정.

### 실행

```bash
# Option A — 수동
git -C ~/robot mv <child>/wiki/<lesson>.md wiki/
git -C ~/robot commit -m "promote: <lesson> to global wiki"

# Option B — 헬퍼 (추천)
~/robot/scripts/promote.sh <child>/wiki/<lesson>.md
```

OMC 스킬 연계: `/oh-my-claudecode:remember` (분류) → `promote.sh` (이동) → `/oh-my-claudecode:wiki` (정리).

## 🔍 검색

```bash
rg -l "키워드" ~/robot/wiki/              # Global
rg -l "키워드" ~/robot/<child>/wiki/      # Project-local
```
