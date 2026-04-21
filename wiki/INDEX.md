# Robot Wiki — Global Index

> 모든 robot child 프로젝트가 공유하는 크로스-프로젝트 지식 베이스.
> 각 child의 SessionStart 훅이 이 파일을 자동 로드합니다.

## 📌 Next Session TODO (2026-04-20 세션 3회 핸드오프)

### 🔹 Next Session — `omc-teams` 프로토타입 (2026-04-21 pivot)

**배경**: Session 3에서 role-scoped distillation plan (frontmatter servant 방식)을 실행 시작(Phase A 완료, 커밋 `b01c61e`/`458de9b`) → Phase A-0 실측으로 세 가지 약점 확인:

1. **Native ToolSearch**가 이미 세션 시작 context bloat을 상당 부분 커버 (distillation 핵심 근거 약화).
2. **Servant 호출 per-call 오버헤드(~5k 토큰)**가 MCP 직접 호출(~200 토큰)보다 크게 비쌈 → short op 많은 워크로드에서 순손실.
3. **User-scope agent**는 세션 내 hot-load 불가 — iteration UX 마찰.

→ 사용자 결정: `omc-teams` (OS-level tmux pane 격리, OMC shipped skill) 프로토타입으로 **pivot**. Phase A 산출물 정리 완료 (parent `c3cf7c3`, datafactory `bda537f`).

**다음 세션 할 일** (cwd 자유 — 우선 `cd ~/robot/datafactory && claude`):

1. `/oh-my-claudecode:omc-teams` 스킬 doc 정독.
2. 최소 프로토타입: 2-pane 팀 (planner pane + isaac-worker pane, 각 pane 자체 cwd + `.mcp.json`).
3. 구체 태스크 1개 시험 — 예: Phase 1 smoke (`get_scene_info` + 10-line `execute_script` + `connect_to_robot` + `get_topics`).
4. 측정: per-pane 토큰 사용량, UX 체감, tmux 운영 오버헤드.
5. 판정:
   - **우수** → omc-teams를 도메인 격리 메커니즘으로 확정, 아키텍처 doc 재작성.
   - **열등** → Claude Code 네이티브(cwd-scoped `.mcp.json` + ToolSearch)만 사용, 격리 레이어 스킵. 도메인 작업에 직접 착수.

**보존된 참조 자료**:
- `~/robot/datafactory/.omc/specs/deep-interview-robot-omc-role-scoped-distillation.md` — 요구사항 레벨 spec (planner 연구 도구 유지, servant 도메인 MCP, return-value only). **omc-teams 구현에도 유효**.
- `~/robot/datafactory/.omc/plans/open-questions.md` — 3개 generic domain research 항목만 남김 (Robosynx 라이선싱, ros-mcp fork 비교, Anthropic CC 이슈 #16177/#4476/#32514).
- `~/robot/wiki/mcp_lessons.md` §2026-04-21 — user-scope agent hot-load 제약 (트러블슈팅 참조).

**중단된 산출물 (git 히스토리에만 존재)**:
- distillation plan `458de9b` → deleted `bda537f`
- `omc_robot_profile.md` (10-section profile) `b01c61e` → deleted `c3cf7c3`
- 3 servant agents (`~/.claude/agents/isaac-operator.md` 외) → user-scope 삭제 (git 무관)

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

### 🔹 Next Session 2 (SUBSUMED → Session 3, 이후 abandoned) — Q1 MCP 격리 가이드
- 원 범위(서브에이전트 MCP 격리 3-way 우회 비교)는 Session 3 `role-scoped distillation` spec에 흡수 → 2026-04-21 해당 접근 abandoned. 관련 lesson(user-scope agent hot-load 제약)은 `wiki/mcp_lessons.md` §2026-04-21에 보존. 격리 자체는 `omc-teams` 프로토타입에서 재검토.

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
