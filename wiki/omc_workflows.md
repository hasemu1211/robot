# OMC 워크플로우

> oh-my-claudecode 기반 다중 에이전트 워크플로우 패턴. DATAFACTORY Phase 1에서 검증된 조합.

## 3-Stage 파이프라인 (권장)

```
/oh-my-claudecode:brainstorm (또는 deep-interview)
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

## 주요 스킬 요약

| 스킬 | 용도 | 비고 |
|---|---|---|
| `/oh-my-claudecode:deep-interview` | Socratic 요구사항 인터뷰 | ambiguity 수학적 게이팅, 20% 이하면 proceed |
| `/oh-my-claudecode:plan --consensus` | Ralplan 합의 계획 | Planner/Architect/Critic, 최대 5 iter |
| `/oh-my-claudecode:autopilot` | 자율 end-to-end 실행 | Phase 0-5, cancel로 중단 가능 |
| `/oh-my-claudecode:ralph` | Persistence loop with architect verify | acceptance criteria 달성까지 자율 |
| `/oh-my-claudecode:team` | tmux teammate 병렬 실행 | `teammateMode: tmux` 필수 |
| `/oh-my-claudecode:deepinit` | 계층적 AGENTS.md 생성 | 첫 세팅 시 |
| `/oh-my-claudecode:mcp-setup` | MCP 서버 프로젝트별 격리 | 가이드 포함 |
| `/oh-my-claudecode:wiki` | 위키 읽기/쓰기 | scope = 현재 cwd의 `wiki/` |
| `/oh-my-claudecode:verify` | 완료 주장 검증 | 커밋 전 필수 |
| `/oh-my-claudecode:cancel` | 모드 중단 | autopilot/ralph 등 |

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
