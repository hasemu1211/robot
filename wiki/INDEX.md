# Robot Wiki — Global Index

> 모든 robot child 프로젝트가 공유하는 크로스-프로젝트 지식 베이스.
> 각 child의 SessionStart 훅이 이 파일을 자동 로드합니다.

## 📌 Next Session TODO (2026-04-20 세션 2회 핸드오프)

### 🔹 Next Session 1 — Q2 스킬 생태계 Survey & 갭 분석 (parent scope)
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

### 🔹 Next Session 2 — Q1 서브에이전트 MCP 격리 가이드 (child scope)
- **cwd**: `cd ~/robot/datafactory && claude`
- **시작 prompt**: `/oh-my-claudecode:deep-interview` — 우회 3가지 (inline `mcpServers`, EnterWorktree, omc-teams tmux) 선택 기준
- **관련 Anthropic 이슈**: #16177 #4476 (둘 다 open)
- **산출물**: `mcp_isolation.md` 가이드 + 데코레이터/예제 → child `wiki/`에 먼저, 2+ children에 적용 가능하면 `promote.sh`로 global 승격

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
