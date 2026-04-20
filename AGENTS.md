# robot — Parent template repo

> 로봇 관련 프로젝트의 부모 템플릿. 자식 프로젝트(children)는 이 레포 구조를 따르며 OMC 워크플로우와 2-Tier wiki를 공유합니다.

---

## Children (registered)

<!-- bootstrap-child.sh이 등록한 child들 -->
- [datafactory/](datafactory/) — V&V 기반 로봇 비전 합성 데이터 파이프라인 (Isaac Sim 4.5.0 + ROS2 humble, symlinked to `~/Desktop/Project/DATAFACTORY`)

---

## 구조

```
~/robot/
├── scripts/
│   └── bootstrap-child.sh        # 새 child 프로젝트 scaffold
├── wiki/                          # 글로벌 KB (크로스-child 지식)
│   ├── INDEX.md                   # ← SessionStart 훅이 자동 로드
│   ├── isaac_sim_api_patterns.md
│   ├── ros2_bridge.md
│   ├── omc_workflows.md
│   └── mcp_lessons.md
├── .claude/
│   └── settings.json              # 2-Tier wiki 훅 + teammateMode
├── .omc/
│   ├── specs/                     # 설계 사양 (tracked)
│   ├── plans/                     # 구현 계획 (tracked)
│   └── research/                  # 조사 결과 (tracked)
├── CLAUDE.md                      # OMC 기본값 → ~/.claude/CLAUDE.md 참조
└── README.md                      # 레포 사용법
```

## 2-Tier Wiki

- **Global** (`~/robot/wiki/`): 모든 child가 참조하는 크로스-프로젝트 지식 — Isaac Sim API, ROS2 브릿지, OMC 워크플로우, MCP 교훈.
- **Project-local** (`~/robot/<child>/wiki/`): 해당 child 고유의 교훈 — 각 child의 `.claude/settings.json` SessionStart 훅이 global + local 둘 다 자동 로드.

`/oh-my-claudecode:wiki` 스킬은 현재 cwd의 `wiki/` 디렉토리에 읽고 씁니다 → scope는 디렉토리 위치로 결정.

## 새 child 추가

```bash
~/robot/scripts/bootstrap-child.sh <name>
# 또는
~/robot/scripts/bootstrap-child.sh <absolute_path_to_existing_repo>  # 심링크로 등록
```

생성된 child 디렉토리로 진입 후:
```
/oh-my-claudecode:deepinit        # 계층적 AGENTS.md
/oh-my-claudecode:mcp-setup       # 프로젝트 MCP 격리
```

## 도구

- `oh-my-claudecode`: 멀티 에이전트 오케스트레이션 (`deepinit`, `plan`, `autopilot`, `wiki`, `mcp-setup`)
- `superpowers`: `brainstorming`, `writing-plans`, `tdd`, `verification-before-completion`
- `context7`: 외부 API 문서 조회

## 핸드오프 메모

이 레포는 `DATAFACTORY/.omc/specs/deep-interview-robot-setup-repo.md`와 `.omc/plans/robot-setup-repo-plan.md`의 consensus 기반으로 생성되었습니다. 설계 의도는 이 두 문서 참조.
