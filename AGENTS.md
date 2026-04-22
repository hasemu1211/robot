# robot — Parent distribution repo

> 로봇 관련 프로젝트의 **공유 가능한 distribution**. 자식 프로젝트(children)는 이 레포 구조를 따르며 OMC 워크플로우와 2-Tier wiki를 공유합니다.

상세 사용법 + 설치 가이드는 [`README.md`](README.md).

---

## Children (registered)

<!-- bootstrap-child.sh이 등록한 child들 (distribution 자체엔 포함 안 됨) -->

_아직 등록된 child 없음. `./scripts/bootstrap-child.sh <name> --profile=isaac+ros2` 로 생성._

---

## 구조 요약

```
~/robot/
├── scripts/                      # install.sh, doctor.sh, bootstrap-child.sh, merge-dotfiles.sh, promote.sh
├── claude/                       # ~/.claude 주입 소스 (marker-based)
├── dotfiles/                     # wezterm, tmux, xprofile (심링크 소스)
├── templates/                    # child 생성용 파라미터화 템플릿 (docker, .mcp.json, AGENTS.md)
├── vendor/                       # submodule (isaac-sim-mcp @ omni-mcp)
├── external/                     # submodule (3rd-party robotics-agent-skills)
├── wiki/                         # 🌐 global KB (Isaac / ROS2 / MCP / OMC / 호스트 교훈)
├── docs/                         # distribution 사용자 문서 (INSTALL / HOST_PREREQUISITES / ...)
├── .omc/{specs,plans,research}/  # tracked 설계 산출물
├── .env.template                 # secrets 변수 reference (.env.local 은 gitignored)
├── README.md · AGENTS.md · CLAUDE.md · KEYBINDINGS.md · CURATOR_ACCESS.md
```

## 2-Tier Wiki

- **Global** (`~/robot/wiki/`): 모든 child가 참조하는 크로스-프로젝트 지식 — Isaac Sim API, ROS2 bridge, OMC 워크플로우, MCP, 호스트 환경 교훈.
- **Project-local** (`~/robot/<child>/wiki/`): 해당 child 고유의 교훈 — SessionStart 훅이 parent + local 둘 다 자동 로드.

`/oh-my-claudecode:wiki` 스킬은 현재 cwd의 `wiki/`를 읽고 씁니다 → scope는 디렉토리 위치로 결정.

승격 규칙은 [`wiki/INDEX.md`](wiki/INDEX.md) § 승격 규칙 참조.

## 새 child 추가

```bash
./scripts/bootstrap-child.sh <name> --profile=isaac+ros2|ros2|bare
# 또는 기존 레포를 심링크로 등록:
./scripts/bootstrap-child.sh /absolute/path/to/existing-repo
```

생성 후:
```
cd ~/robot/<name>
claude                                    # 2-Tier wiki 자동 로드
/oh-my-claudecode:deepinit                # 계층적 AGENTS.md (선택)
/oh-my-claudecode:mcp-setup               # MCP 격리 (선택 — 템플릿이 이미 기본 구성)
```

## Distribution 도구

- **install.sh** — 전체 distribution 레이어 설치 (host/dotfiles/cli/claude/gemini/vendor/child)
- **doctor.sh** — 레이어 검증 (human + `--json`)
- **merge-dotfiles.sh** — 기존 dotfile과 대화형 통합
- **bootstrap-child.sh** — child scaffold + Docker 템플릿 치환
- **promote.sh** — child wiki → global wiki 승격

## Curator workflow

이 레포의 관리자 역할(외부 환경 감사 → parent 도입 결정)은 `curator-adoption-audit` 스킬이 담당합니다. description-based auto-load 가 실패해도 아래 정보만으로 다음 curator 세션이 재개 가능합니다.

- **스킬 본문**: `.omc/skills/curator-adoption-audit.md` (v2, 180 lines) — Gemini-untrusted-input · Tier A/B/C/D 분류 · 증거 규칙
- **슬래시 커맨드 진입**: `/curator-audit <src> [--scope=mcp,gemini,claude,skill,submodule]`
- **행동 규칙 (스킬 본문 §실행 단위 분할 / §Install-Doctor 대칭 / §재감사 루프)**:
  - entity 당 **atomic 커밋** (submodule 1개 = 커밋 1개, 한 덩어리로 묶지 말 것)
  - `install.sh` 레이어 추가 시 `doctor.sh check_<name>()` **동반 수정** (처방-측정 대칭)
  - Tier B 실행 직후 `wiki/INDEX.md` · `.gitignore` · 주석 등에서 **stale 레퍼런스 재스캔**
- **진행 중 TODO**: `.omc/plans/curator-tier-c-backlog-20260422.md` (C-1~C-4)
- **검증 훅**: `scripts/hook-validate-edit.sh` 이 `.sh` syntax + `.md` frontmatter 를 자동 점검 (PostToolUse, 편집 차단 X)

## 외부 의존

- `oh-my-claudecode`: 멀티 에이전트 오케스트레이션 (`deepinit`, `plan`, `autopilot`, `wiki`, `mcp-setup`, `remember`)
- [Agent Cookbook](wiki/agent_cookbook.md) — **(필독)** 실제 toolbox 카탈로그 + 레시피 + 관례
- `superpowers`: `brainstorming`, `writing-plans`, `tdd`, `verification-before-completion`
- `context7`: 외부 API 문서 조회 (Isaac Sim, ROS2, NumPy 등)
- `rtk`: Claude Code Bash 훅 토큰 압축 (install.sh cli 레이어에 포함)

## 설계 문서

distribution 자체의 설계 근거:

- `.omc/specs/deep-interview-robot-distribution.md` — deep-interview spec (ambiguity 13.75% PASSED)
- `.omc/plans/robot-distribution-plan.md` — consensus-approved 구현 계획 (iter 2 final)
- `.omc/research/skill-gap-analysis-20260420.md` — 생태계 갭 분석
- `wiki/ecosystem_survey.md` — 플러그인·스킬·MCP 카탈로그

초기 parent repo 부트스트랩 시 (distribution 전 단계):
- `.omc/specs/deep-interview-robot-setup-repo.md` (history)
- `.omc/plans/robot-setup-repo-plan.md` (history)
- [test-project/](test-project/) — new child (scaffolded 2026-04-21)
