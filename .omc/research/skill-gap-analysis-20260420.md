# Skill Gap Analysis — 2026-04-20

> 5계층 ecosystem survey (`wiki/ecosystem_survey.md`) 후속. Adopt/Trial/Build 결정 근거와 제안 4건.

## 스코프

- **Parent**: `~/robot/` (로봇 child 템플릿 부모).
- **Child 1**: `~/robot/datafactory/` (Isaac Sim 4.5.0 + ROS2 humble 비전 합성 데이터).
- **제약**: MCP 서브에이전트 격리는 아직 미해결 (Anthropic #16177 / #4476).

## 결정 ① — superpowers 플러그인 유지 여부

### 결정: **유지 (keep)** — 선택적 숨기기는 차후 옵션

**근거**:
- INDEX.md는 "tdd만 유니크"라고 가정했으나 재확인 결과 **유니크 스킬 4개**:
  - `test-driven-development` — OMC 대응 없음.
  - `receiving-code-review` — 리뷰 수신 프로토콜. OMC는 `code-reviewer` agent가 송신 쪽만 다룸.
  - `finishing-a-development-branch` — 브랜치 종료 체크리스트. `release`와 범위 다름.
  - `brainstorming` — softer 대안. `deep-interview`(수학 ambiguity 게이팅)가 우월하나 **가벼운 explore엔 유효**.
- 나머지 9개는 OMC 중복 (plan/executing/debugging/parallel/git-worktrees/verification 등). 중복이 해롭진 않음 — 서로 다른 "입구"로 같은 disciplines에 도달.
- 제거 비용: 훅 재구성, 슈퍼파워에만 바인딩된 디폴트 워크플로우(`using-superpowers` 시작 게이트) 재설계 필요.
- **리스크**: deprecated alias 3건(`brainstorm`, `write-plan`, `execute-plan`)이 문서에 섞여 있음 → 이번 턴에 `omc_workflows.md`에서 정리.

**조건부 재검토 트리거**: 3개월 뒤 OMC에 `tdd` 스킬이 추가되면 superpowers 축소 재평가.

---

## 결정 ② — Exa MCP 도입 여부

### 결정: **트라이얼 도입 (Tier-2)** — parent 전용, child는 옵트인

**근거**:
- 이번 survey에서 built-in WebSearch가 5/5 쿼리에 대해 작동 OK였으나, 의미론적 깊이(논문/repo 발견)는 부족. Exa의 embedding-rank가 ecosystem 조사·문헌 탐색에 우위.
- 자유 티어 1k searches/mo — survey 한 번에 ~10건이면 월 100회 세션 커버.
- 설치: `/plugin marketplace add exa-labs/exa-mcp-server && /plugin install exa-mcp-server` + `EXA_API_KEY`.
- Scope: parent `~/robot/.mcp.json`에 등록 시 child까지 상속 → 원치 않으면 parent-only로 제한.

**비용/위험**: API 키 관리, 벤더 락-인 (낮음 — WebSearch fallback 존재), 레이턴시 (낮음, Exa는 < 2s p95).

**미도입 시 대안**: 현재 WebSearch로 충분. Exa는 "논문·repo 디스커버리가 반복되면 추가" 트리거로.

---

## 결정 ③ — 신규 스킬/MCP shortlist (우선순위)

### Priority 1 (이번 세션 또는 다음 1주)
1. **Docker MCP Toolkit** 도입
   - 명령: `/plugin install docker-mcp-toolkit@docker`
   - 선결: Docker Desktop 4.62+ 확인 (`docker version`).
   - 효용: rosbridge 컨테이너 (포트 9090) natural-language 관리, datafactory Compose ops.
2. **`omc_workflows.md` § 주요 스킬 요약 확장** (Q2 산출물)
   - deprecated alias 정리, 유니크/중복 매핑표 추가, Exa/Docker MCP 추가.
3. **MCP isolation 가이드** (Q1 child scope)
   - `~/robot/datafactory/wiki/mcp_isolation.md`에 3가지 우회 (inline `mcpServers`, `EnterWorktree`, omc-teams tmux) 비교.

### Priority 2 (2–4주)
4. **Exa MCP 트라이얼** — parent scope 도입, survey/research 세션에서 체감 차이 기록.
5. **Context7 library coverage 감사** — `resolve-library-id("ros2")`, `("isaac-sim")`, `("mcp-python-sdk")` 실행하여 커버리지 wiki 기록.
6. **filesystem MCP per-child** — datafactory에서 ros2 bag 디렉토리 scope로 추가.

### Priority 3 (여유 생기면)
7. **Robosynx/Isaac Monitor** 탐색 — 2026-04 공개 상용/OSS? 우리 스택과 차이.
8. **NVIDIA 포럼 MCP 튜토리얼** 우리 `mcp_lessons.md`에 교차검증 기록.

---

## 결정 ④ — 커스텀 `/robot:*` 스킬 (skill-creator 대상)

### 제안 A: `/robot:promote` ★ (highest-leverage)
- **트리거**: child `wiki/` 내 교훈이 2+ child에 적용 가능할 때.
- **본문**: INDEX.md의 "승격 체크리스트" 테이블 자동 실행 → `scripts/promote.sh <file>` 호출 → INDEX.md 자동 갱신.
- **skill-creator로**: 기존 `promote.sh`를 wrap. `remember` 스킬과 체이닝.

### 제안 B: `/robot:isaac-api-guard`
- **트리거**: Isaac Sim Python 스크립트 수정 전/후.
- **본문**: `wiki/isaac_sim_api_patterns.md`의 4.2→4.5 패치 테이블을 기준으로 static check (ast_grep) → 위반 경고. `create_robot` lazy import, mcp 1.27 signature break 등 기존 경험 룰 내장.
- **필요 도구**: `ast_grep_search` (이미 사용 가능).

### 제안 C: `/robot:ros2-smoke`
- **트리거**: child bootstrap 직후, MCP 설정 변경 후.
- **본문**: Isaac Sim MCP 8766 + rosbridge 9090 + `execute_script` BLOCKING smoke. 지난 세션 워크플로우 증류.
- **가치**: 승격 체크리스트의 "재현 가능한 추상 패턴" 해당.

### 제안 D: `/robot:mcp-isolate` (Q1 후속)
- **트리거**: 서브에이전트가 MCP 필요할 때.
- **본문**: 3가지 우회(`mcpServers` inline / `EnterWorktree` / `omc-teams` tmux) decision tree. `mcp_isolation.md` 작성 후 증류.
- **전제**: Next Session 2 수행 결과.

**우선순위**: A > B > C > D (D는 선결작업 필요). A는 이번 턴 이후 바로 skill-creator로 드래프트 가능.

---

## Action checklist (next-session 핸드오프)

- [ ] Docker MCP Toolkit 설치 & rosbridge 컨테이너에서 smoke (`docker mcp` tools).
- [ ] Exa MCP 트라이얼 결정 (EXA_API_KEY 획득 → parent `.mcp.json` 등록).
- [ ] `/robot:promote` 스킬 드래프트 (skill-creator + `promote.sh` wrap).
- [ ] `omc_workflows.md` deprecated alias 정리 (이번 턴 완료).
- [ ] INDEX.md § "Next Session TODO" Q2 완료 표시 + Q1 착수 준비.

---

## 참고

- `wiki/ecosystem_survey.md` — 전체 T1–T5 카탈로그.
- `wiki/mcp_lessons.md` — mcp 1.27 호환 패치.
- `wiki/isaac_sim_api_patterns.md` — 4.2→4.5 API 매핑.
- Anthropic 이슈 #16177, #4476 — 서브에이전트 MCP 격리 미해결.
