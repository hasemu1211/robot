# Robot Wiki — Global Index

> 모든 robot child 프로젝트가 공유하는 cross-project 지식 베이스.
> `~/robot/.claude/settings.json` SessionStart 훅이 이 파일을 자동 로드.
> parent 세션에서는 Project wiki 재주입 생략 (중복 방지).

## 📌 Next Session Plan (2026-04-21, 2-세션 워크플로우)

병렬 세션 2개:

- **A** (`cd ~/robot/datafactory && claude`) — 하위 프로젝트 **OMC 재셋업**.
  이전 role-scoped distillation 접근 폐기 (`c3cf7c3` / `bda537f`). `/plan` 또는 `/oh-my-claudecode:omc-setup`부터 기획 다시 시작.
  요구사항 spec은 `~/robot/datafactory/.omc/specs/deep-interview-robot-omc-role-scoped-distillation.md`에 보존 (planner/servant 분업 아이디어 자체는 유효).
- **B** (`cd ~/robot && claude`) — **parent 인프라 보강**.
  audit 결과 누락: `~/robot/.mcp.json` (없음), `.env` 또는 환경 변수 템플릿 (없음), `bootstrap-child.sh`의 MCP 시드 옵션 (없음).
  결정·구현: planner-only 의도 문서화, 공통 env 템플릿, bootstrap 시 MCP 후보 선택 메뉴.

## 🧩 Children Status

| Child | 상태 | 최근 commit | Next action |
|---|---|---|---|
| `datafactory/` | Phase 1 smoke PASS · role-scoped distillation abandoned 2026-04-21 | `bda537f` | OMC 재셋업 (Session A) |

향후 children 추가 시 이 표에 1행씩 append. 자식 INDEX 전체 주입은 하지 않음 — 필요 시 `cat ~/robot/<child>/wiki/INDEX.md`로 직접 조회.

## 🧠 설치된 외부 스킬

- 소스: `~/robot/external/robotics-agent-skills` (shared 3rd-party clone, `arpitg1304/robotics-agent-skills`).
- datafactory 주입: `~/robot/datafactory/.claude/skills/`에 9개 심볼릭 (ros1 제외).
  - `ros2`, `docker-ros2-development`, `ros2-web-integration`, `robotics-design-patterns`, `robotics-testing`, `robot-perception`, `robot-bringup`, `robotics-security`, `robotics-software-principles`.
- Claude Code 진행 시 description trigger로 auto-load (progressive disclosure — 세션 시작 오버헤드는 description 합계만, 본문은 호출 시 로드).

## 📚 교훈 & 레퍼런스

- [Isaac Sim API 패턴](isaac_sim_api_patterns.md) — 4.5.0 API 경로, 4.2→4.5 패치, Kit extension 로딩
- [ROS2 Bridge](ros2_bridge.md) — rosbridge Docker 이미지, 포트 9090, DDS 자동 발견
- [OMC 워크플로우](omc_workflows.md) — deepinit/plan/autopilot 파이프라인, 2-Tier wiki, tmux teammate 모드
- [MCP 교훈](mcp_lessons.md) — mcp 1.27.0 호환성 패치, MCP extension 활성화, user-scope agent hot-load 제약 (2026-04-21)
- [생태계 Survey](ecosystem_survey.md) — T1–T5 플러그인/스킬/MCP 카탈로그

## 🔄 승격 규칙 (Child → Global)

### 분류 체크리스트

| 질문 | Yes → | No → |
|---|---|---|
| 2개 이상의 child에 적용 가능한가? | 승격 후보 | child-local 유지 |
| 프로젝트 고유 수치/경로/설정 포함? | child-local 유지 | 승격 후보 |
| 재현 가능한 추상 패턴인가? | 승격 후보 | child-local 유지 |
| 다른 프로젝트에 프라이버시 문제? | 절대 승격 X | — |
| 두 번째 작성 중인가? | 즉시 승격 | 한 번 더 겪으면 재평가 |

3개 이상 yes → 승격 강력 추천. 1–2개 yes → borderline, 1세션 관찰 후 결정.

### 실행

```bash
# Option A — 수동
git -C ~/robot mv datafactory/wiki/some_lesson.md wiki/
git -C ~/robot commit -m "promote: some_lesson.md to global wiki"

# Option B — 헬퍼 (추천)
~/robot/scripts/promote.sh datafactory/wiki/some_lesson.md
```

OMC 스킬 연계: `/oh-my-claudecode:remember` (분류) → `promote.sh` (이동) → `/oh-my-claudecode:wiki` (정리).

## 🔍 검색

```bash
rg -l "키워드" ~/robot/wiki/              # Global
rg -l "키워드" ~/robot/<child>/wiki/      # Project-local
```
