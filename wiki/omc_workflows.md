# OMC 워크플로우

> oh-my-claudecode 기반 다중 에이전트 워크플로우 패턴. DATAFACTORY Phase 1에서 검증된 조합.

## 3-Stage 파이프라인 (권장)

```
/oh-my-claudecode:deep-interview  (또는 superpowers:brainstorming)
  → 요구사항 크리스탈화 (Socratic Q&A, ambiguity ≤ 20%)
  → spec in .omc/specs/

/oh-my-claudecode:plan --consensus --direct
  → Planner/Architect/Critic 3-단계 합의 루프 (최대 5 iterations)
  → plan in .omc/plans/ (RALPLAN-DR + ADR 포함)

/oh-my-claudecode:autopilot --plan .omc/plans/<name>.md --skip-phase 0,1
  → Phase 2 Execution (Ralph + Ultrawork)
  → Phase 3 QA cycling
  → Phase 4 Multi-perspective validation
  → Phase 5 Cleanup
```

각 단계는 독립 실행 가능. 중간 결과물은 `.omc/{specs,plans,research}/`에 영속.

## 주요 스킬 요약 (2026-04-20 ecosystem survey 기준)

### OMC 핵심 (Tier-0)

| 스킬 | 용도 | 비고 |
|---|---|---|
| `/oh-my-claudecode:deep-interview` | Socratic 요구사항 인터뷰 | ambiguity 수학적 게이팅, 20% 이하면 proceed |
| `/oh-my-claudecode:plan --consensus` (alias `ralplan`) | 합의 계획 | Planner/Architect/Critic, 최대 5 iter |
| `/oh-my-claudecode:autopilot` | 자율 end-to-end 실행 | Phase 0-5, cancel로 중단 가능 |
| `/oh-my-claudecode:ralph` | Persistence loop with architect verify | acceptance criteria 달성까지 자율 |
| `/oh-my-claudecode:team` / `ultrawork` / `ccg` | 병렬 실행 계열 | tmux teammate 또는 다중모델 |
| `/oh-my-claudecode:deepinit` | 계층적 AGENTS.md 생성 | 첫 세팅 시 |
| `/oh-my-claudecode:mcp-setup` | MCP 서버 프로젝트별 격리 | 가이드 포함 |
| `/oh-my-claudecode:wiki` | 위키 읽기/쓰기 | scope = 현재 cwd의 `wiki/` |
| `/oh-my-claudecode:verify` | 완료 주장 검증 | 커밋 전 필수 |
| `/oh-my-claudecode:trace` / `deep-dive` | 원인 추적 + 요구사항 합성 | sim/hardware 버그 |
| `/oh-my-claudecode:remember` / `learner` / `skillify` | 지식 증류 | child→global 승격 판단, 세션→스킬 |
| `/oh-my-claudecode:external-context` / `sciomc` | 병렬 조사 | document-specialist N개 병렬 |
| `/oh-my-claudecode:ai-slop-cleaner` | LLM slop 정리 | 회귀 안전 삭제 우선 |
| `/oh-my-claudecode:visual-verdict` | 스크린샷 비교 | Isaac 렌더 회귀 검사 |
| `/oh-my-claudecode:cancel` | 모드 중단 | autopilot/ralph 등 |

### superpowers 유니크 (OMC 대응 없음)

| 스킬 | 용도 | 비고 |
|---|---|---|
| `superpowers:test-driven-development` | TDD | OMC에 TDD 전용 스킬 없음 → 유지 |
| `superpowers:receiving-code-review` | 리뷰 수신 프로토콜 | OMC `code-reviewer` agent는 송신 쪽 |
| `superpowers:finishing-a-development-branch` | 브랜치 종료 체크리스트 | `release`와 범위 다름 |
| `superpowers:brainstorming` | 가벼운 explore | `deep-interview`가 더 엄격한 대안 |

### Deprecated aliases (사용 금지)

- `/oh-my-claudecode:brainstorm` → 존재 **안** 함 (INDEX.md에 Q2 노트).
- `superpowers:brainstorm` → `superpowers:brainstorming`.
- `superpowers:write-plan` → `superpowers:writing-plans`.
- `superpowers:execute-plan` → `superpowers:executing-plans`.

### MCP 서버 (이 레포 관련)

| MCP | 상태 | 비고 |
|---|---|---|
| Isaac Sim MCP (port 8766) | 운영 | mcp 1.27 호환 패치 필요 (`mcp_lessons.md`) |
| rosbridge (port 9090) | 운영 | ROS2 humble Docker 이미지 |
| `context7` | 플러그인 | `resolve-library-id` / `query-docs` |
| `github-mcp-server` | 운영 | issue/PR/repo |
| Docker MCP Toolkit | **도입 후보** | `/plugin install docker-mcp-toolkit@docker` |
| Exa MCP | **트라이얼 후보** | `/plugin marketplace add exa-labs/exa-mcp-server` |

세부 shortlist: `wiki/ecosystem_survey.md`. 결정 근거: `.omc/research/skill-gap-analysis-20260420.md`.

## 2-Tier Wiki 패턴

- **Global** (`~/robot/wiki/`): 크로스-프로젝트 지식
- **Local** (`~/robot/<child>/wiki/`): 프로젝트 고유 교훈

SessionStart 훅이 둘 다 자동 로드:
```bash
PARENT=$HOME/robot
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PARENT")
{ echo "## Global wiki"; cat "$PARENT/wiki/INDEX.md"
  echo "## Project wiki"; cat "$ROOT/wiki/INDEX.md"
  echo "## AGENTS.md"; cat "$ROOT/AGENTS.md"
} | jq -Rs '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: .}}'
```

승격(promotion): `git mv <child>/wiki/X.md ~/robot/wiki/` — 2개 이상 child에 적용 가능한 지식.

## tmux teammate 모드

```json
// ~/.claude/settings.json (또는 프로젝트 .claude/settings.json)
{
  "teammateMode": "tmux",
  "env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}
}
```

`/oh-my-claudecode:team 3` 실행 시 tmux pane 3개 생성, 각 pane이 다른 cwd에서 기동되면 프로젝트별 MCP 격리 가능 (Anthropic 이슈 #16177 미해결, 부분 동작).

## OMC 산출물 경로 (per-repo scoping)

| 경로 | 추적 | 용도 |
|---|---|---|
| `.omc/specs/` | tracked | 설계 사양 |
| `.omc/plans/` | tracked | 구현 계획 |
| `.omc/research/` | tracked | 조사 결과 |
| `.omc/state/` | gitignored | runtime 상태 |
| `.omc/sessions/` | gitignored | session log |
| `.omc/logs/` | gitignored | 실행 로그 |
| `.omc/notepad.md` | gitignored | 메모장 |
| `.omc/project-memory.json` | gitignored | 프로젝트 메모리 캐시 |

디렉토리 위치 = scope. 부모(`~/robot/`)와 자식(`~/robot/<child>/`) 각각 독립 `.omc/`.

## Hooks 주의

OMC 플러그인이 `PreToolUse`/`PostToolUse`로 자동 productivity nudge 주입 (병렬 실행 힌트 등). 이는 스킬 워크플로우의 의도된 게이트가 아닌 조언. 핵심 게이트는 skill 내부 로직.
