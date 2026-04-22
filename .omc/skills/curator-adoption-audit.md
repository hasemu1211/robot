---
name: curator-adoption-audit
description: ~/robot/ parent distribution 관리자가 child 레포 또는 외부 환경(Gemini CLI, MCP 서버, npm/PyPI 패키지, Claude config) 산출물을 parent 로 도입할지 판단할 때 호출. Gemini 출력은 untrusted input 으로 취급하고 git remote origin / PyPI METADATA / HTTP citation / 파일 실존으로 모든 주장을 교차검증해 환각을 차단. 결과는 Tier A(즉시 승격) / B(인프라 갭) / C(파라미터화) / D(도입 X) 분류표와 구체 destination 경로로 산출. 사용자가 "뭐 가져와야", "반영할거 조사", "도입 후보", "child 산출물 검토", "promote to parent", "adopt to distribution", "audit parent" 같은 표현을 쓰거나 parent 레포 관리자 관점으로 외부 환경을 감사하는 맥락이면 명시적 스킬 호출이 없어도 발동.
triggers:
  - "도입 후보"
  - "child 산출물"
  - "승격"
  - "반영할거"
  - "뭐 가져와야"
  - "curator 관점"
  - "promote to parent"
  - "adopt to distribution"
  - "audit parent"
---

# curator-adoption-audit

Curator (parent distribution 관리자) 가 외부 환경의 산출물을 parent 로 도입할지 **증거 기반**으로 판단하는 고정 절차. 자연어 직감이 아니라 git/PyPI/HTTP/파일 실존을 교차검증해 hallucination 을 차단한다.

## 호출 조건

사용자 메시지에 다음 중 하나라도 있을 때:
- "child/X 프로젝트에서 뭐 가져와야"
- "도입 후보", "반영할거 조사", "승격", "promote to parent", "adopt to distribution"
- curator 역할로 parent 에 반영 결정 요청

호출 금지: 단순 구조 설명, 단일 파일 열람, 버그 조사.

## 입력 스캔 (병렬 1회, 중복 호출 금지)

```
- 출처 tree:           find <src> -maxdepth 3 -not -path './.git*' -not -path './.omc*'
- 출처 git history:    git -C <src> log --oneline -40
- 출처 config 파일:    .mcp.json, .gemini/settings.json, GEMINI.md, .gitignore, .gitmodules
- parent 현상:         ls ~/robot/{scripts,claude,gemini,templates,wiki,docs,external,vendor}
- parent 정책:         ~/robot/wiki/INDEX.md, ~/robot/AGENTS.md, ~/robot/.gitignore
```

## 증거 규칙 (RED FLAGS 차단)

왜 이 규칙이 존재하는가: `wiki/omc_omg_boundary.md §1-2` — Gemini 는 같은 세션에서 두 번이나 존재하지 않는 GitHub 이슈 URL 을 합성했다. 자기-반성은 재발 방지에 효과 없음 → 검증은 구두 계약이 아니라 파일·HTTP 게이트로 구조화한다.

| 주장 유형 | 검증 방식 | 실패 시 처리 |
|---|---|---|
| "X 레포 사용 중" | `git -C <path> remote -v` → origin URL 비교 | 주장 폐기 (도입 표에서 제외) |
| "X PyPI 패키지 사용 중" | `~/.cache/uv/**/<pkg>*/METADATA` 또는 `pip show`, README 배지의 GitHub 레포 확인 | 주장 폐기 |
| "X submodule 등록됨" | `.gitmodules` 존재 + entry 존재 확인. 디렉토리만 있다고 등록된 것 아님 | B-tier 갭으로 기록 |
| Gemini 출력 내 citation URL | `curl -I <url>` → 2xx/3xx 만 수용 | invalid 분리, 0건이면 전체 반려 |
| "이미 구현됨" (parent) | Glob + 실제 파일 read. `ls` 가 "(empty)" 반환해도 glob 로 재확인 | 없으면 B-tier |

**원칙**: **Gemini 출력 = untrusted input.** Gemini 가 workspace 밖 파일 못 읽을 때 직접 read 로 전환, Gemini 가 합성한 내용 인용 금지.

## 분류 — Tier A/B/C/D

각 Tier 의 철학:

- **A = cross-project 가치 + 파라미터화 불필요** — 그대로 복제해도 재현성 확보
- **B = 이미 실사용되는데 distribution 에 등록 안 됨** — "디렉토리만 있지 `.gitmodules` 없음" 같은 갭. 새 머신에서 clone → install 하면 누락. 도입이 아니라 **보수**
- **C = 부분 재사용 + 경로·이름·포트 분리 필요** — raw copy 하면 충돌. `${VAR}` 치환 지점 식별이 핵심
- **D = 프로젝트 고유·시크릿·upstream-owned** — 도입하면 오염. 명시적으로 "도입 X" 로 분류해 다음 curator 가 재논의 안 하도록 고정

| Tier | 정의 | Parent 내 destination 예시 |
|---|---|---|
| **A** | 즉시 승격 | `wiki/`, `docs/`, `scripts/install.sh` 신규 레이어 |
| **B** | 인프라 갭 보강 | `.gitmodules`, `install.sh` 의 `git submodule update` 호출 |
| **C** | 선별 도입, 파라미터화 | `templates/**/*.tmpl` (경로·포트·이름 `${VAR}` 치환) |
| **D** | 절대 도입 X | — (시크릿·런타임·upstream-owned·프로젝트 고유 기획) |

## 출력 계약

Tier 표 + 각 항목에 **concrete destination path** + 처리 방식 한 줄. 개별 항목 예시:

```
| # | 항목 | 출처 | parent 목적지 | 처리 방식 |
|---|------|------|---------------|-----------|
| 1 | .omc/scripts/omg-bridge.sh | <src>/.omc/scripts/omg-bridge.sh | templates/omc/scripts/omg-bridge.sh.tmpl | env 이미 분리됨, 그대로 복제 |
```

마지막에 **사용자 확인 질문** (submodule URL, tag pin 여부, 실행 단위 A→B→C 순서).

## 성공 기준

1. Tier 표의 각 "사용 중" 주장이 `git remote` 또는 PyPI METADATA 또는 파일 실존으로 뒷받침됨 (증거 미제시 주장 0)
2. D-tier 에 시크릿·런타임·upstream-owned 자산이 전부 분류됨 (누락 시 보안 사고)
3. parent destination path 가 실제 parent tree 와 정합 (hallucinated path 0)
4. 사용자 승인 전 어떤 파일도 수정·커밋하지 않음

## 주의 (seen in practice)

- `ls` 가 harness 에서 "(empty)" 만 반환하는 환경 있음 → Glob tool 로 재검증
- Gemini headless (`-p`) 는 cwd 외 read 실패 → `--include-directories` 추가하거나 그냥 직접 read 하는 편이 빠름
- datafactory 경험: 9개 스킬이 `.claude/skills/` 에 심링크로 존재하지만 타겟(`external/robotics-agent-skills`) 이 parent `.gitignore` 에 제외됨 → 새 clone 시 **스킬 0개**. 반드시 B-tier 로 기록
- DF `.gitignore` 의 `.omc/state/*` 세분화 정책 (tracked state 허용, runtime 제외) 이 parent 의 통째 제외보다 우수 — curator 는 이런 "parent 의 거친 규칙" 도 B-tier 로 플래그

## Worked example — datafactory + Gemini extension 감사 (2026-04)

실제 이 스킬이 재현해야 하는 플로우. 출처 2곳: `~/Desktop/Project/DATAFACTORY` + `~/.gemini/` host.

1. **입력 스캔** — `find` + `git log -40` + `.mcp.json`·`GEMINI.md`·`.gitignore` 읽음. host 는 `ls ~/.gemini/extensions/` 로 OMG extension `oh-my-gemini-cli` v0.8.1 발견.
2. **증거 교차검증**:
   - `git -C ~/robot/isaac-sim-mcp remote -v` → `omni-mcp/isaac-sim-mcp` ✅
   - `git -C ~/robot/external/robotics-agent-skills remote -v` → `arpitg1304/robotics-agent-skills` ✅
   - `~/.cache/uv/**/ros_mcp-3.0.1.dist-info/METADATA` → README 배지 `robotmcp/ros-mcp-server` ✅
   - Gemini 가 앞서 workspace 제약으로 "DATAFACTORY 읽음" 이라 허위 보고 → **폐기**, 직접 read 로 전환
3. **Tier 분류** (14개 항목):
   - A: `wiki/omc_omg_boundary.md`, `install.sh gemini 레이어`, OMG extension 설치 자동화, `.gitignore` 정교화
   - B: `external/robotics-agent-skills` submodule 미등록, `vendor/isaac-sim-mcp` 비어있음
   - C: `.omc/scripts/omg-bridge.sh`, `/start` skill, `scripts/start-session.sh`, `.gemini/settings.json` child 템플릿
   - D: `~/.gemini/google_accounts.json`, `~/.gemini/tmp/**`, `~/.gemini/extensions/oh-my-gemini-cli/**` 내부, DF `V&V 기획.md`
4. **destination 매핑**: 각 항목에 `wiki/<name>.md`, `templates/omc/skills/<name>.md.tmpl`, `scripts/install.sh gemini` 등 구체 경로 명시
5. **사용자 확인 질문**: submodule URL 2개, OMG tag pin 버전, 실행 단위 A→B→C 순서
6. **승인 후에만 커밋**: 이번 세션은 `docs(wiki): add robotics MCP alternatives to ecosystem_survey` 1건만 먼저 진행 (Tier C 의 일부)

## Distribution 전파 경로

1. (draft) `~/.claude/skills/omc-learned/curator-adoption-audit.md` ← 여기
2. (promote) `~/robot/.omc/skills/curator-adoption-audit.md` ← project-scoped 사본
3. (distribute) `~/robot/claude/skills/curator-adoption-audit/SKILL.md` ← install.sh 가 `~/.claude/skills/` 로 전파
4. (slash-command wrap) `~/robot/claude/commands/curator-audit.md` ← `/curator-audit <src>` 호출 엔트리

## 오픈 이슈 (스킬 초안 단계)

- **slash command naming**: `/curator-audit` vs `/robot:audit` vs `/omc:adopt` 중 최종 결정 필요 → 현 방향: `/curator-audit` (간결, 오해 소지 적음)
- **install.sh `claude/skills/` 레이어 설계**: marker-merge 방식이 `claude/commands/` 와 대칭인지 `~/.claude/skills/` 는 디렉토리 단위라 심링크가 더 적절한지 미정
- **argument 형태**: `/curator-audit <src>` 단일 인자 vs `/curator-audit --src=<path> --scope=mcp,skill` 구조화 인자 → 현 방향: positional + `--scope=` 옵션
