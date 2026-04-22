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

## 실행 단위 분할

Tier 표 승인 후 커밋은 **entity 단위** 로 쪼갠다. 왜:

- 각 entity 변경이 독립 검증 가능 (예: submodule 추가는 `git submodule status`, install.sh 는 `bash -n` / dry-run)
- 한 entity 실패 시 다른 것 영향 없이 revert 가능
- git log 가 "왜 이 변경이 들어왔는지" 를 추적 가능

나쁜 예: "Tier B 전부 한 커밋으로 묶음" → 실패 포인트 식별 어려움 + 부분 revert 불가.

좋은 예 (2026-04-22 세션): submodule isaac-sim-mcp → 커밋 #1 · submodule robotics-agent-skills → 커밋 #2 · install.sh vendor 레이어 수정 → 커밋 #3. 3개 독립 커밋.

## Install/Doctor 대칭

`scripts/install.sh` 에 새 레이어를 추가하면 **같은 커밋 (또는 직후 커밋)** 에 `scripts/doctor.sh check_<name>()` 도 추가. 반대 방향도 동일.

왜: install 은 "처방" · doctor 는 "측정". 둘 중 하나만 있으면:
- install 만 → 설치 후 상태 확인 수단 없음 → regression 탐지 불가
- doctor 만 → WARN/FAIL 만 누적, 복구 수단 없음

이번 세션 구체적 적용: `run_gemini()` 신설 커밋 직후 `check_gemini()` 커밋. `ALL_LAYERS` / `LAYERS` 배열 양쪽 동기화도 함께.

## 재감사 루프

Tier B (인프라 갭) 실행 직후에는 parent 현상이 바뀌었으므로 **A/C 를 다시 스캔한다**:

- Tier B 로 등록한 submodule 덕분에 Tier A 의 destination 경로·참조가 stale 될 수 있음
- 스테일 레퍼런스는 grep 으로 추적:
  - `wiki/INDEX.md` 의 "전환 예정" / "TODO" / "Phase B pending"
  - `.gitignore` 의 legacy 심링크 exclusion
  - 코드 코멘트의 "will migrate" / "pending"
- 발견 시 같은 세션에서 후속 커밋으로 업데이트 (다음 curator 가 또 발견하지 않도록)

"한 번 Tier 표 만들고 끝" 이 아니라 **"실행 → 재스캔 → 추가 승격"** 의 루프. 이번 세션에서도 submodule 전환 후 INDEX.md "submodule 전환 예정" 줄을 같은 라운드에 "등록 완료 (HEAD 8b3dfcb)" 로 갱신함.

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
- **pre-existing bug 발견 시 scope 결정**: 파일을 touch 하다가 관련 없는 부분에 syntax error / orphan 블록을 발견하면, (a) 동일 커밋에 fix 포함 (작고 명확하면) · (b) 별도 이슈로 플래그 (침투적·위험하면) 중 택. 2026-04-22 install.sh 의 끝부분 duplicate `main "$@"` 블록 (`bash -n` 실패 유발) 은 (a) 로 처리 — 크기 작고 기능 없는 쓰레기라 파일 hygiene 차원에서 즉시 제거
- **blast radius 매핑**: 한 entity 도입·변경은 보통 여러 파일을 건드림. submodule 추가 사례: `.gitmodules` + `.gitignore` (exclusion 제거) + `scripts/install.sh vendor 레이어` + `scripts/doctor.sh check_vendor` + `wiki/INDEX.md` (스테일 라인) + 필요 시 `README.md` 의 submodule 안내 문단. destination 을 단수로 적지 말고 **"영향 파일 리스트"** 로 검증

## Worked example #1 — datafactory + Gemini extension 감사 (2026-04)

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

## Worked example #2 — 시급 A/B follow-up 8-commit 체인 (2026-04-22)

example #1 이후 사용자 승인 하에 Tier A/B 실행 단계. "실행 단위 분할" · "Install/Doctor 대칭" · "재감사 루프" 규칙이 실전 적용된 흐름:

1. `b2bb2d4 feat(curator): skill + /curator-audit command` — 본 스킬 자체의 초안 + 슬래시커맨드 wrapper
2. `b7753fb feat(vendor): isaac-sim-mcp submodule` — 심링크 제거 + `.gitmodules` 등록 + HEAD 6653138 pin + `.gitignore` 라인 제거 (entity 단위 1개)
3. `4a69a23 feat(external): robotics-agent-skills submodule` — 로컬 clone 제거 + fresh `git submodule add` + HEAD 8b3dfcb pin + `.gitignore` 라인 제거 (entity 단위 1개)
4. `72ade42 fix(install): vendor layer + orphan tail prune` — run_vendor() 가 두 submodule 인지 + 사전 존재하던 `bash -n` 실패 유발 orphan block 제거 (주의 §"pre-existing bug" 의 (a) 처리)
5. `4502f15 docs(omg): promote boundary + integration spec` — Tier B 완료 후 **재감사 루프** 가 발동, wiki/INDEX.md 의 stale 문구 ("submodule 전환 예정") 도 같은 라운드에 정정
6. `e54e819 feat(install): gemini layer` — 새 install.sh 레이어 (run_gemini: CLI check + OMG tag pin + settings deep-merge + trustedFolders 등록)
7. `ab01193 feat(doctor): gemini checks` — **Install/Doctor 대칭 규칙** 적용. check_gemini(cli · omg-extension · settings · trusted-folders) + help 문자열의 mcp 누락 보수
8. (post-audit) `install.sh --step=gemini --yes` 실제 실행 → doctor 4/4 green 확인. **smoke test 후에만 "작업 완료" 선언**

증거·검증 예시:
- submodule 전환 시 DF `.claude/skills/*` 9개 심링크를 `readlink -f` 로 모두 재검증 → 경로 유지 확인 후 진행
- install.sh 편집마다 `bash -n` + `--step=<layer> --dry-run --yes` 재실행
- deep-merge 전후 `~/.gemini/settings.json` 의 `security.auth` 보존 확인 (seed 에 auth 없으므로 구조적 안전)

## Distribution 전파 경로

1. (draft) `~/.claude/skills/omc-learned/curator-adoption-audit.md` ← 여기
2. (promote) `~/robot/.omc/skills/curator-adoption-audit.md` ← project-scoped 사본
3. (distribute) `~/robot/claude/skills/curator-adoption-audit/SKILL.md` ← install.sh 가 `~/.claude/skills/` 로 전파
4. (slash-command wrap) `~/robot/claude/commands/curator-audit.md` ← `/curator-audit <src>` 호출 엔트리

## 오픈 이슈 (스킬 초안 단계)

- **slash command naming**: `/curator-audit` vs `/robot:audit` vs `/omc:adopt` 중 최종 결정 필요 → 현 방향: `/curator-audit` (간결, 오해 소지 적음)
- **install.sh `claude/skills/` 레이어 설계**: marker-merge 방식이 `claude/commands/` 와 대칭인지 `~/.claude/skills/` 는 디렉토리 단위라 심링크가 더 적절한지 미정
- **argument 형태**: `/curator-audit <src>` 단일 인자 vs `/curator-audit --src=<path> --scope=mcp,skill` 구조화 인자 → 현 방향: positional + `--scope=` 옵션
