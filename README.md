# robot — 로봇 개발 부모 템플릿 레포

OMC(oh-my-claudecode) 기반 로봇 프로젝트 개발을 위한 template parent repository. 자식 프로젝트들은 이 레포의 구조, 2-Tier wiki, OMC 워크플로우를 상속합니다.

## 빠른 시작

```bash
cd ~/robot
claude                                    # SessionStart 훅이 global wiki + AGENTS.md 자동 로드
```

자식 프로젝트 내에서:

```bash
cd ~/robot/<child>
claude                                    # SessionStart 훅이 global + local wiki 모두 로드
```

## 새 child 프로젝트 추가

### (a) 새로 생성

```bash
~/robot/scripts/bootstrap-child.sh mynewrobot
cd ~/robot/mynewrobot
/oh-my-claudecode:deepinit                # 계층적 AGENTS.md
/oh-my-claudecode:mcp-setup               # 프로젝트 MCP 격리
```

### (b) 기존 레포를 심링크로 등록

```bash
~/robot/scripts/bootstrap-child.sh /absolute/path/to/existing/repo
# → ~/robot/repo → /absolute/path/to/existing/repo 심링크 생성
```

## 구조

```
~/robot/
├── scripts/bootstrap-child.sh
├── wiki/                    # 🌐 Global KB
├── .claude/settings.json    # 2-Tier wiki 훅
├── .omc/                    # 설계 산출물 (specs/plans/research tracked)
└── <child1>/                # 자식 프로젝트 (독립 git repo 또는 심링크)
    ├── wiki/                # 🔒 Project-local KB
    ├── .claude/             # child 고유 설정
    └── .mcp.json            # child 고유 MCP
```

## 2-Tier Wiki

- **Global** (`~/robot/wiki/`): Isaac Sim, ROS2, OMC, MCP 등 크로스-프로젝트 지식
- **Local** (`<child>/wiki/`): 해당 child 고유 교훈

SessionStart 훅이 cwd 기준으로 parent + local 둘 다 자동 주입.

## 등록된 자식들

- **datafactory** — V&V 합성 데이터 파이프라인 (Isaac Sim 4.5.0 + ROS2 humble)
  - 심링크 타겟: `~/Desktop/Project/DATAFACTORY`
  - 상세: `~/robot/datafactory/AGENTS.md`

## OMC 스킬 (이 레포에서 자주 쓰는)

| 스킬 | 용도 |
|---|---|
| `/oh-my-claudecode:deepinit` | 계층적 AGENTS.md 자동 생성 |
| `/oh-my-claudecode:mcp-setup` | MCP 서버 프로젝트별 격리 |
| `/oh-my-claudecode:wiki` | 현재 cwd의 wiki/ 읽기/쓰기 |
| `/oh-my-claudecode:plan --consensus` | Ralplan 3-단계 합의 계획 |
| `/oh-my-claudecode:autopilot` | 계획 기반 자율 실행 |

## 설계 문서

- `~/Desktop/Project/DATAFACTORY/.omc/specs/deep-interview-robot-setup-repo.md` — 원본 deep-interview spec (이 레포의 존재 이유)
- `~/Desktop/Project/DATAFACTORY/.omc/plans/robot-setup-repo-plan.md` — consensus-approved 구현 계획 (Architect PASS + Critic APPROVE)

## 환경 요구사항

- Linux (Ubuntu 22.04+ 권장)
- tmux 3.2+, xclip, xsel
- Node.js 20+, Claude Code CLI, OMC 4.13+
- WezTerm (use_ime=true, IBus autostart) 권장
- Docker + NVIDIA Container Toolkit (child 프로젝트가 Isaac Sim 쓸 때)
