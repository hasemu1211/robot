# Tier C Backlog — Curator 2026-04-22

> 2026-04-22 curator 세션에서 Tier A/B 는 실행 완료 (10 commits, 2ace2e6..ba66257), Tier C 는 다음 세션으로 연기. 이 문서는 **actionable TODO + 증거 트레일** 로, 다음 세션이 context 복원 없이 이어갈 수 있게 작성됨.
>
> 세션 종결 시점 parent HEAD: `ba66257 feat(hook): PostToolUse validator for .sh syntax + .md frontmatter`
>
> 관련 스킬: `curator-adoption-audit` v2 (`~/robot/.omc/skills/curator-adoption-audit.md`) — Tier C 정의 및 실행 규칙("실행 단위 분할", "재감사 루프", "blast radius") 참조.

---

## 개요

Tier C = "부분 재사용 + 경로·이름·포트 분리 필요". raw copy 하면 충돌이라 `${VAR}` 치환 지점 식별이 핵심. Tier A/B 와 달리 **child 템플릿** 형태로 들어가며 `bootstrap-child.sh` 가 복사 시점에 치환.

Destination 공통: `~/robot/templates/omc/**` (신설 하위 트리 필요).

---

## C-1: /start skill + start-session.sh 템플릿화

**출처 (DF)**:
- `~/Desktop/Project/DATAFACTORY/.omc/skills/start.md` (127 lines) — 리터럴 `/start` 만 호출되는 anti-misfire 디스패처. resume/kickoff/stale-hint/infra-only/ambiguous 5-모드
- `~/Desktop/Project/DATAFACTORY/scripts/start-session.sh` (99 lines) — GPU/docker preflight + MCP readiness polling (isaac-sim :8766, rosbridge :9090) + MCP 로그 string 검증
- DF commit `9cb14b5 feat(start-skill): session entry dispatcher + container health script`

**Destination (parent)**:
- `~/robot/templates/omc/skills/start.md.tmpl`
- `~/robot/templates/scripts/start-session.sh.tmpl`

**파라미터화 지점**:
```
${COMPOSE_PROJECT_NAME}   # child 디렉토리명. bootstrap-child.sh 가 치환
${ISAAC_MCP_PORT:-8766}   # isaac-sim MCP 포트. child 마다 충돌 회피
${ROSBRIDGE_PORT:-9090}   # rosbridge websocket 포트
${PREFLIGHT_GPU:-1}       # GPU 검사 on/off (GPU 없는 child 지원)
```

**blast radius**:
- `~/robot/scripts/bootstrap-child.sh` 에 복사 로직 추가 (envsubst 또는 sed)
- `~/robot/docs/ROBOTICS_SKILLS.md` 에 `/start` 스킬 설명 추가 (선택)

**완료 기준**: 새 child `bootstrap-child.sh newchild --profile=isaac+ros2` → `newchild/.omc/skills/start.md` 에 `${COMPOSE_PROJECT_NAME}` 치환된 `newchild` 가 들어있음 + `start-session.sh` 실행 가능

---

## C-2: omg-bridge.sh + pending_research.md.template 템플릿화

**출처 (DF)**:
- `~/Desktop/Project/DATAFACTORY/.omc/scripts/omg-bridge.sh` (147 lines, v3.3)
- `~/Desktop/Project/DATAFACTORY/.omc/state/pending_research.md.template`
- DF commit `5a8b96a feat(omc-omg): establish Claude↔Gemini boundary with bridge v3.3`
- DF commit `d679f37 chore(phase2-kickoff): ... bridge env var docs`

**Destination (parent)**:
- `~/robot/templates/omc/scripts/omg-bridge.sh.tmpl` ← 사실상 raw copy (env 분리 완료)
- `~/robot/templates/omc/state/pending_research.md.template`

**파라미터화 지점**: 실질적으로 0. 이미 env 분리된 상태:
```
OMG_BRIDGE_MODEL     # default: gemini-2.5-flash-lite
OMG_BRIDGE_TIMEOUT   # default: 180s
```
bootstrap 시 치환 없이 복사만 하면 됨.

**선결 조건**:
- `~/robot/docs/OMG_INTEGRATION.md` §3 에 이미 "child 는 `.omc/scripts/omg-bridge.sh` (향후 parent template 에 포함 예정) 로 Gemini 를 호출" 이라 기록됨 — 이 commit 이 "예정" 을 실제로 만듦

**blast radius**:
- `bootstrap-child.sh` 에 `.omc/scripts/` 디렉토리 생성 + 복사 로직
- `docs/OMG_INTEGRATION.md` 의 "향후 parent template 에 포함 예정" 문구 제거 (재감사 루프 규칙 적용)

**완료 기준**: 새 child 에서 `cat .omc/scripts/omg-bridge.sh` 가 147 lines 동일 내용 출력, `bash .omc/scripts/omg-bridge.sh` 실행 가능

---

## C-3: AGENTS.md 에 "외부 지식 4계층" 섹션

**출처 (DF)**:
- DF commit `29cefb3 docs(knowledge-tier): formalize 4-tier external knowledge hierarchy`
- DF AGENTS.md "§외부 지식 계층" 섹션 (별도 파일로 grep 필요, commit show 로 확인 가능)

**우선순위 정의 (commit msg 요약)**:
```
T1 NotebookLM CLI  (private curated, 가장 신뢰)
T2 context7 MCP    (공식 docs, 주간 업데이트)
T3 omg-bridge      (Gemini 웹 grounding + HTTP citation gate)
T4 WebFetch        (fallback, untrusted)

Trust-level 원칙: private curated > web untrusted
```

**Destination (parent)**:
- `~/robot/AGENTS.md` 에 새 `## 외부 지식 4계층` 섹션 추가 (기존 섹션 순서는 수정 안 건드림)

**blast radius**:
- parent `AGENTS.md` 만 수정 (단일 파일)
- `wiki/INDEX.md` 에는 반영 X (AGENTS.md 자체가 SessionStart 훅으로 로드됨)

**완료 기준**: `grep "외부 지식" ~/robot/AGENTS.md` 가 새 섹션을 찾음. 다음 세션 SessionStart 훅으로 자동 주입됨

---

## C-4: Gemini lessons 두 파일 머지

**출처**:
- parent `~/robot/wiki/gemini_lessons.md` (일반 — JSON-RPC/Pydantic/module 탐색)
- DF `~/Desktop/Project/DATAFACTORY/wiki/lessons_gemini.md` (프로젝트 특화 — MCP port 8766, ROS 조작, RTX 5060)

**Destination (parent)**:
- `~/robot/wiki/gemini_lessons.md` (기존 파일 확장)

**머지 원칙**:
- DF 고유 수치는 **제거** (포트·컨테이너명·GPU 모델 등)
- 추상 패턴은 **유지** (ROS 토픽 조회 패턴, 컨테이너 부팅 타이밍 관찰 등)
- parent 본문에 "§2. 운영 실전 (DATAFACTORY-derived)" 같은 부섹션 추가

**blast radius**:
- parent `wiki/gemini_lessons.md` 만 수정
- DF 파일은 그대로 유지 (child-local)
- `wiki/INDEX.md` 는 이미 링크 있음 — 수정 불필요

**완료 기준**: parent `wiki/gemini_lessons.md` 가 기존 일반 내용 + DF 추상 레슨 포함. DF 고유 수치(8766·9090·RTX 5060) 0건.

---

## 실행 순서 권장 (재감사 루프 기반)

1. **C-2 먼저** — 파라미터화 0건이라 가장 쉽고, `docs/OMG_INTEGRATION.md` 의 "향후 포함 예정" 문구 해소
2. **C-3** — 단일 파일 편집. AGENTS.md 에 새 섹션 append
3. **C-1** — 가장 복잡 (2개 파일 + 4개 파라미터 + bootstrap-child.sh 수정)
4. **C-4** — wiki 머지. 순서 상관 없음, 언제든 가능

각 entity 당 **독립 커밋** (skill v2 "실행 단위 분할" 규칙 적용).

---

## 다음 세션 재개 체크리스트

- [ ] `git log --oneline` 으로 HEAD 확인 (현재 `ba66257` 기준)
- [ ] 이 파일 읽기 (`cat .omc/plans/curator-tier-c-backlog-20260422.md`)
- [ ] `/curator-audit ~/Desktop/Project/DATAFACTORY --scope=skill,script` 로 C-1/C-2 재검증
- [ ] 사용자 확인 후 C-2 부터 실행
- [ ] 실행 후 이 계획 파일의 해당 섹션을 "✅ completed in commit <SHA>" 로 업데이트 (또는 파일 삭제)

---

## 참조

- skill: `~/robot/.omc/skills/curator-adoption-audit.md` v2 (Worked example #2 이 본 세션 8-commit 체인 요약)
- DF 소스 커밋: `9cb14b5`, `5a8b96a`, `d679f37`, `29cefb3`
- parent 세션 커밋 체인: `89091ab..ba66257` (10 commits, 2026-04-22)
