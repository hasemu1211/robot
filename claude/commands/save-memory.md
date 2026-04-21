# save-memory (robot distribution)

**먼저 `/oh-my-claudecode:remember` 를 우선 고려하세요.** 분류·저장 판단이 더 체계적입니다.
이 명령은 robot distribution 고유의 **3-tier 라우팅** 안내만 담습니다 (OMC remember 결과를 어디에 쓸지 결정).

## 라우팅 (robot distribution)

**1차 — wiki (repo-tracked, 공유 가능)** 
- 현재 cwd가 parent (`~/robot`) → `wiki/INDEX.md` + `wiki/lessons_<category>.md` (global)
- 현재 cwd가 child (`~/robot/<child>`) → `./wiki/INDEX.md` + `./wiki/lessons_<category>.md` (project-local)
- 2개 이상 child 적용 가능한 지식 → `~/robot/scripts/promote.sh <child>/wiki/<file>.md`

**2차 — Claude Code auto-memory (머신 local)**
- 시스템 프롬프트의 auto memory 섹션이 경로를 관리 — 수동 경로 계산 불필요
- user / feedback / project / reference 타입 사용 (frontmatter 포함)
- **주의**: 머신마다 경로 다름, repo에 공유 안 됨 → "재사용 불가하지만 다음 세션에는 필요" 레벨

**3차 — `.omc/notepad.md`** (gitignored, 임시)
- 분류 미완인 메모. 주기적으로 1차/2차로 이동.

## 기존 OMC 도구와의 관계

- **`/oh-my-claudecode:remember`** — 분류 워크플로우 (무엇을 어디에 저장할지 판단). **우선 호출**.
- **`/oh-my-claudecode:wiki`** — 현재 cwd의 `wiki/` 읽기/쓰기. remember가 wiki로 가라고 판단하면 이걸로 실행.
- **project-memory hooks** — `.omc/project-memory.json` 자동 관리 (SessionStart/PreCompact/PostTool). 수동 개입 불필요.
- 이 `save-memory` 명령은 **위 세 가지를 조합**할 때 robot distribution의 wiki scope 규칙을 리마인드하는 용도.

## 한 줄 워크플로우

```
/oh-my-claudecode:remember           # 분류
  → wiki? → /oh-my-claudecode:wiki    (scope = 현재 cwd의 wiki/)
  → auto-memory? → system prompt auto memory 규칙 (Write tool)
  → notepad? → `.omc/notepad.md` (임시, 재분류 필요)
```

저장할 내용 없으면: **"이번 세션에서 새로 저장할 내용 없음"** 보고.
