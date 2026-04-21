# Robot Wiki — Global Index

> 모든 robot child 프로젝트가 공유하는 크로스-프로젝트 지식 베이스.
> 각 child의 SessionStart 훅이 이 파일을 자동 로드합니다.

## 📌 Next Session TODO (2026-04-20 세션 3회 핸드오프)

### 🔹 Next Session 3 — Role-scoped distillation autopilot (**시작 지점**, 세션 2에서 결정·문서화 완료)

- **cwd**: `cd ~/robot/datafactory && claude` ⚠️ (**parent 아님, child에서 시작**)
  - 이유: parent `~/robot/.mcp.json`는 없음. datafactory `.mcp.json`에 isaac-sim + ros-mcp — planner 세션에 도메인 MCP를 로드하려면 datafactory cwd 필요.
  - SessionStart hook가 parent + child wiki 양쪽 모두 자동 주입.
- **즉시 확인 파일**:
  - `~/robot/datafactory/.omc/specs/deep-interview-robot-omc-role-scoped-distillation.md` — spec (ambiguity 18%, 5 라운드)
  - `~/robot/datafactory/.omc/plans/robot-omc-role-scoped-distillation-plan.md` — plan iter2 + **session-2 amendments AM-1~5** (Architect+Critic APPROVE)
  - `~/robot/datafactory/.omc/plans/open-questions.md` — 6 open
- **✅ 세션 2에서 이미 결정된 것 (Plan Session-2 amendments에 기록)**:
  - **AM-1 Schema**: OMC convention **γ (`disallowedTools:`)** 채택이 default. β(`tools:`)는 필요 시 allow-list 보조. α(`allowedTools:`)는 static evidence 0이라 기각.
  - **AM-2 Agent 정의 위치**: `~/.claude/agents/` (유저 스코프) — 모든 robot child에서 발견, OMC 내장과 동급. `~/robot/.claude/agents/`는 발견 안 됨.
  - **AM-3 세션 cwd**: `~/robot/datafactory/` (위 참조).
  - **AM-4 AC-5 Case B 재정의**: 시스템 차단 불가 (isaac-sim이 세션에 로드). 정책은 **규율 기반** — planner 직접 호출 건수 audit (기대 0). 2회 위반 시 방식 Y(tmux pane) migration.
  - **AM-5 Revisit trigger**: N-child 환경 또는 규율 위반 2회 → 방식 Y(`omc-teams` tmux) 마이그레이션 고려.
- **시작 prompt** (autopilot 자동 재개):
  ```
  /oh-my-claudecode:autopilot --plan ~/robot/datafactory/.omc/plans/robot-omc-role-scoped-distillation-plan.md --skip-phase 0,1
  ```
  첫 행동: Phase A-0 empirical probe — 하지만 γ 채택 거의 확정이라 probe는 "γ가 실제 declaratively 작동함" 확인용 (α/β는 skip 가능).
- **Open decision (세션 3 첫 turn에 사용자 확정 필요)**:
  1. γ 단독 vs β+γ 병용 (2단계 방어 선호 여부)
  2. `docker-operator` servant default 포함 여부 (open-questions #6)
- **컨텍스트 절약 팁**: 세션 2 deep-interview / ralplan 전체 내용은 spec + plan에 응축. 새 세션은 위 3개 파일만 읽으면 재개 가능.
- **autopilot Branch STOP 조건**: A-0에서 모든 schema가 silent이면 에스컬레이션 (plan).

### 🔹 Next Session 1 (DONE 2026-04-20) — Q2 스킬 생태계 Survey & 갭 분석
- **cwd**: `cd ~/robot && claude`
- **Scope**: 내부 큐레이션이 아닌 **생태계 전수 조사** (T1~T5):
  - **T1 내부**: 현재 enabled 플러그인 25+ 스킬 description·use-case 수집
  - **T2 생태계**: Isaac Sim / ROS2 / 로봇 특화 3rd-party 스킬·플러그인·MCP — `WebSearch`, `WebFetch`, GitHub MCP
  - **T3 공식**: Anthropic marketplace, superpowers/OMC upstream 최신 상태
  - **T4 갭 분석**: 필요한데 없는 것 → `skill-creator`/`skillify` 후보 spec 초안
  - **T5 MCP 후보**: Exa (웹서치 품질↑), Docker MCP, PyBullet/Gazebo/MoveIt 등 로봇 MCP
- **도구 (이미 사용 가능)**:
  - `WebSearch`, `WebFetch` — 네이티브 deferred tools (Claude Code 기본 제공, Exa 없어도 OK)
  - `mcp__github-mcp-server__search_repositories` — 이미 연결
  - `context7` — 공식 문서 lookup
  - `/oh-my-claudecode:external-context` — document-specialist 병렬 조사
- **주의**: `/oh-my-claudecode:brainstorming`은 존재하지 않음. `brainstorm`은 deprecated(deep-interview alias). survey 성격이라 deep-interview/brainstorming 모두 과함 — 직접 대화로 진행.
- **예시 쿼리**:
  - `WebSearch: "Claude Code plugin Isaac Sim"`
  - `WebSearch: "oh-my-claudecode skill robotics"`
  - `WebSearch: "MCP server ROS2 Gazebo MoveIt"`
  - `GitHub search: topic=claude-code topic=robotics`
- **결정 포함**: ①슈퍼파워 플러그인 유지 여부 (tdd만 유니크) ②Exa MCP 도입 ③도입할 신규 스킬/MCP 후보 shortlist ④만들어야 할 커스텀 스킬 (e.g., `/robot:promote`, `/robot:isaac-api-guard`)
- **산출물**:
  - `~/robot/wiki/omc_workflows.md` § 주요 스킬 요약 확장 (T1)
  - `~/robot/wiki/ecosystem_survey.md` 신설 (T2-T5)
  - `~/robot/.omc/research/skill-gap-analysis-<date>.md`
  - 필요 시 후속 세션용 spec 초안

### 🔹 Next Session 2 (SUBSUMED → Session 3) — Q1 MCP 격리 가이드
- 원 범위(서브에이전트 MCP 격리 3-way 우회 비교)는 Next Session 3의 `role-scoped distillation` spec에 흡수. `mcp_isolation.md` 단독 작성 대신, `omc_robot_profile.md` §9 scope schema branch record + `wiki/mcp_lessons.md` A-0 entry로 증류.

### 세션 진행 요령
- 새 세션에서 SessionStart 훅이 이 INDEX.md 자동 주입 → 맥락 이어짐
- Context 부담되면 새 세션 중에도 `/clear` (state 디스크에 있어 resume OK)
- `/oh-my-claudecode:cancel`로 autopilot/ralph 중단 가능

## 지난 세션 성과 (2026-04-20)
- Deep-interview spec (ambiguity 11.25%, 6 rounds)
- Ralplan v3.1 consensus plan (Architect PASS + Critic APPROVE, 4 iterations)
- ~/robot/ parent repo created (commits: eacfce2 → 5df7f8d)
- DATAFACTORY → ~/robot/datafactory symlink migration (atomic 8fa75a5)
- 2-Tier wiki 훅 + bootstrap-child.sh + promote.sh
- BLOCKING smoke 통과 (Isaac Sim MCP 8766 + ROS2 9090 + execute_script 4.5)
- WezTerm picker: ~/robot/* 스캔 + robot (parent) 첫 항목

## 교훈 & 레퍼런스

- [Isaac Sim API 패턴](isaac_sim_api_patterns.md) — 4.5.0 API 경로, 4.2→4.5 패치, Kit extension 로딩
- [ROS2 Bridge](ros2_bridge.md) — rosbridge Docker 이미지, 포트 9090, DDS 자동 발견
- [OMC 워크플로우](omc_workflows.md) — deepinit/plan/autopilot 파이프라인, 2-Tier wiki, tmux teammate 모드
- [MCP 교훈](mcp_lessons.md) — mcp 1.27.0 호환성 패치, MCP extension 활성화 방식, 서버 디버깅
- [생태계 Survey 2026-04-20](ecosystem_survey.md) — T1–T5 플러그인/스킬/MCP 카탈로그 + shortlist (Q2 산출물, 세부 근거는 `.omc/research/skill-gap-analysis-20260420.md`)
- [OMC Robot Profile](omc_robot_profile.md) — Planner/Servant 역할 경계 + 3-Layer 구조 + 서번트 매트릭스 (AC-4 산출물, 세션 3~ Phase A–D)

## 승격 규칙 (promotion) — Child → Global

### 분류 체크리스트 (승격 전에 자문)

| 질문 | Yes → | No → |
|---|---|---|
| 이 교훈이 **2개 이상의 child에 적용 가능한가?** | 승격 후보 | child-local 유지 |
| 프로젝트 고유 수치/경로/설정 포함? (e.g., 특정 camera K값) | child-local 유지 | 승격 후보 |
| **재현 가능한 추상 패턴**인가? (e.g., Docker MCP 연결, Isaac Sim API 변경) | 승격 후보 | child-local 유지 |
| 다른 프로젝트에 **프라이버시 문제** 있나? (회사/고객 정보, license) | 절대 승격 X | (승격 후보는 유지) |
| 해당 교훈을 **반복 작성**한 적 있는가? (두 번째 작성 중이면 yes) | 즉시 승격 | 한 번 더 겪으면 재평가 |

3개 이상 yes → 승격 강력 추천. 1-2개 yes → borderline, 1세션 관찰 후 결정.

### 승격 실행

```bash
# Option A — 수동 (단순)
git -C ~/robot mv datafactory/wiki/some_lesson.md wiki/
git -C ~/robot commit -m "promote: some_lesson.md to global wiki"

# Option B — 헬퍼 스크립트 (추천)
~/robot/scripts/promote.sh datafactory/wiki/some_lesson.md
#   → 승격 가치 pre-flight 스캔 (다른 파일에서의 참조 확인)
#   → 확인 후 git mv + commit
#   → INDEX.md 자동 갱신
```

### OMC 스킬 연계

```
cd ~/robot/datafactory
/oh-my-claudecode:remember         # 분류: 어느 교훈이 승격 후보인지 판단
  ↓ (상위 체크리스트 적용)
~/robot/scripts/promote.sh <file>  # 실제 승격
  ↓
/oh-my-claudecode:wiki             # parent wiki에서 정리 (필요 시)
```

**장기 (2+ children 생긴 후)**: `/oh-my-claudecode:skillify`로 이 워크플로우를 `/robot:promote` 커스텀 스킬로 증류 가능.

## 검색 팁

```bash
rg -l "키워드" ~/robot/wiki/       # Global
rg -l "키워드" ~/robot/<child>/wiki/  # Project-local
```
