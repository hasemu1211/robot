# CLAUDE.md — robot parent

OMC 기본 설정은 `~/.claude/CLAUDE.md`에서 상속됩니다.

이 레포는 **로봇 개발 부모 템플릿**입니다. 자세한 구조 및 워크플로우는 `AGENTS.md` 참조.

## Session 시작 시 자동 주입 (SessionStart 훅)

- `~/robot/wiki/INDEX.md` — Global wiki 인덱스
- `<cwd>/wiki/INDEX.md` — Project-local wiki 인덱스 (child 내부에서만 존재)
- `<cwd>/AGENTS.md` — 프로젝트 지침

## OMC 주요 스킬 (이 레포에서 권장)

- `/oh-my-claudecode:deepinit` — 계층적 AGENTS.md 자동 생성
- `/oh-my-claudecode:mcp-setup` — 프로젝트 MCP 격리 설정
- `/oh-my-claudecode:wiki` — 위키 읽고 쓰기 (scope = 현재 cwd의 wiki/)
- `/oh-my-claudecode:plan --consensus` — Ralplan (Planner/Architect/Critic) 계획
- `/oh-my-claudecode:autopilot` — 계획 기반 자율 실행
