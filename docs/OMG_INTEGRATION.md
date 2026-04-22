# OmG Integration Specification

> robot distribution 에서 Claude Code(OMC) 와 Gemini CLI(OmG, `oh-my-gemini-cli`) 간의 책임 분리(SoC) 및 상호운용성 프로토콜. 모든 child 가 참조.
> 교훈 집약은 [wiki/omc_omg_boundary.md](../wiki/omc_omg_boundary.md).

## 1. Scope

- OMC = Claude Code + `oh-my-claudecode` 플러그인
- OmG = Gemini CLI + `oh-my-gemini-cli` extension (tag `v0.8.1` 이상 권장)
- 두 모델을 동시 사용하는 child 에서 반복 발생하는 커맨드 충돌 · 역할 혼선을 구조적으로 해소

## 2. 책임 경계 및 운용 규약

### 2.1 중복 커맨드 충돌 회피 규칙

OMC 와 OMG 에 동명 커맨드가 14개 존재. primary lane 고정:

| Command | Primary Lane | 근거 |
| :--- | :--- | :--- |
| `team` | **Claude** | 최종 의사결정 · 실행 오케스트레이션 |
| `ralph` | **Claude** | V&V 기반 고정밀 논리 플래닝 |
| `plan` / `ralplan` | **Claude** | 합의 기반 계획 (Planner / Architect / Critic) |
| `ultrawork` | **Gemini** | 대량 리포 스캔 · 초안 생성 시 토큰 효율 |
| `research` | **Gemini** | 웹 grounding + citation |
| `context-optimize` | **Gemini** | 컨텍스트 압축 |

위 외의 OMG 전용 커맨드는 간섭 없음.

### 2.2 역할 분담 (Role Matrix)

- **OmG (Gemini)**: Deep Scanner, Doc Grounder, Context Compressor, TDD Boilerplate generator
- **OMC (Claude)**: Architect, Executor, Final Verifier, State Manager

핵심: **상태 관리 · 최종 쓰기 결정은 Claude 전속**. Gemini 의 모든 산출물은 파일로 출력 → Claude 가 검증 후 반영.

### 2.3 Skill vs Command 구분

OMG extension v0.8.1 의 54개 엔트리 중 9종은 **description-trigger 기반 auto-activate Skill** (명시적 `/omg:*` 호출 없이 자연어로 발동):

- `research`, `context-optimize`, `deep-dive`, `execute`, `learn`, `omg-plan`, `plan`, `prd`, `ralplan`

child 는 Skill 로만 쓸지 Command 로 쓸지 선택. 중복 정의된 Skill 이 OMC 와 겹치면 2.1 primary lane 규칙 적용.

### 2.4 Gemini 연구 트리거 정식 경로

OMC 세션에서 Gemini 를 통한 연구·조사를 실행하는 경로는 3가지로 제한:

| 경로 | 실행 방식 | 용도 |
| :--- | :--- | :--- |
| **(A) Skill Trigger** | 자연어 프롬프트 내 연구 키워드 포함 | 일상적 정보 수집 · API 조회 |
| **(B) Team Assembly** | `/omg:team-assemble` 커맨드 호출 | `researcher` 에이전트 레인 구성 · 팀 단위 과업 |
| **(C) Direct Persona** | `agents/researcher.md` 페르소나 직접 지정 | 특정 리서치 과업에 정밀한 페르소나 주입 |

**모든 경로의 출력**은 `.omc/state/gemini_distill.json` 또는 `.omc/state/gemini_*.md` 로 파일 저장 → OMC 가 citation 검증 후 반영.

## 3. 핸드오프 프로토콜

child 는 `.omc/scripts/omg-bridge.sh` (향후 parent template 에 포함 예정) 로 Gemini 를 호출:

- jq 기반 envelope 파싱
- 모든 citation URL 에 `curl -I` HTTP 게이트 → 2xx/3xx 만 수용, 0건이면 `exit 2`
- `finished_at` · `token_usage` 는 bridge 가 덮어씀 (Gemini 값 신뢰 X)

상세 설계는 `wiki/omc_omg_boundary.md §2`.

## 4. 쓰기 권한 ACL (child 의 GEMINI.md 에 반드시 명시)

Gemini 에게 허용된 쓰기 경로:
- `.omc/state/gemini_distill.json`
- `.omc/state/gemini_*.md`
- `.omc/state/pending_research.md`

**쓰기 금지 (Claude 전속)**:
- `.omc/scripts/**` — 브릿지 · 검증 · 오케스트레이션 스크립트
- `.omc/specs/**` — 사양 문서
- `.omc/plans/**`, `.omc/logs/**`
- 루트 계약 파일: `AGENTS.md`, `GEMINI.md`, `CLAUDE.md`

위반 시 OMC 가 즉시 롤백 + `.omc/state/boundary-violations.md` 에 append.

## 5. Changelog

- **v1.1** (2026-04-22, DATAFACTORY): Skill/Command 구분 명시, 연구 트리거 3경로 확정
- **v1.2** (2026-04-22, parent promotion): DATAFACTORY-specific 표현 제거, distribution-neutral 로 재작성. `oh-my-gemini-cli` tag v0.8.1 기준 명시
