# Robot Wiki — Global Index

> 모든 robot child 프로젝트가 공유하는 크로스-프로젝트 지식 베이스.
> 각 child의 SessionStart 훅이 이 파일을 자동 로드합니다.

## 📌 Next Session TODO (2026-04-20 세션 2회 핸드오프)

### 🔹 Next Session 1 — Q2 스킬 검토 & 매핑 (parent scope)
- **cwd**: `cd ~/robot && claude`
- **시작 prompt**: `/oh-my-claudecode:brainstorming` — OMC + superpowers + skill-creator 스킬 전수 검토, 중복/사용빈도/robot 적합성 분류
- **heavy lookup**: `/oh-my-claudecode:external-context` 또는 `document-specialist` 병렬
- **결정 포함**: 슈퍼파워 플러그인 유지 여부 (tdd만 유니크; 나머지는 OMC 대응 있음)
- **산출물**: `~/robot/wiki/omc_workflows.md` § 주요 스킬 요약 확장

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
