# CURATOR_ACCESS — robot 레포 관리자 세션 접근법

> **"curator 세션" = ~/robot/ (parent)에서 돌아가는 Claude Code 세션.** 다른 tmux 창에서 진행 중인 child 작업을 너가 보고·검토·parent 레포에 반영하는 조정자 역할.

---

## 1. 핵심 흐름도

```
┌──────────────────────────────────────────────┐
│ tmux 창 1: CURATOR   cd ~/robot && claude    │ ← 지금 네가 대화하는 내가 여기 있음
│ tmux 창 2: child1    cd ~/robot/datafactory  │ ← 작업
│ tmux 창 3: child2    cd ~/robot/<other>      │ ← 작업
│ ...                                          │
└──────────────────────────────────────────────┘

작업 흐름:
  child에서 git commit → 너가 curator에 와서 "X 반영해줘" →
  curator가 git log/diff 읽고 parent 정책/wiki 업데이트 → commit
```

---

## 2. 처음부터 curator 열기 (새 컴퓨터 부팅 후 등)

```bash
# (옵션) tmux 서버 시작
tmux new-session -s robot -n curator

# curator 창에서
cd ~/robot
claude
```

세션 시작 시 SessionStart 훅이 자동 주입:
- `~/robot/wiki/INDEX.md` (global wiki + Next Session TODO)
- `~/robot/AGENTS.md` (navigation)

그 다음 첫 프롬프트 예시:
```
나 curator 세션으로 돌아왔어. 지난번 상태 요약하고 할 일 제안해줘.
```

---

## 3. 기존 tmux 세션에 다시 attach (컴퓨터 슬립 후 깨어났을 때)

```bash
tmux list-sessions                    # 세션 목록
tmux attach -t robot                  # robot 세션에 재접속
#   또는
tmux a                                # 마지막 세션 attach
```

세션 생존 조건:
- ✅ SSH 끊김, wezterm 닫힘, suspend/hibernate
- ❌ 컴퓨터 shutdown/reboot — tmux 서버 죽음

---

## 4. 다음날 이어하기 (컴퓨터 껐다 켠 경우)

tmux 세션 사망 → Claude 대화도 사망. 하지만 **산출물은 git + .omc/에 영속**.

### 옵션 A — `claude --continue` (같은 cwd의 최근 대화 복구)
```bash
cd ~/robot        # curator 스코프로 돌아감
claude --continue # 어제 대화 이어열기 (토큰 많을 수 있음)
```
- 장점: 어제 대화 맥락 일부 복원
- 단점: cwd별 기억. `cd ~/robot/datafactory`에서는 child 대화가 이어짐

### 옵션 B — 완전 새 세션 (권장, 토큰 절약)
```bash
cd ~/robot
claude
# 첫 프롬프트:
# "INDEX.md 읽었어. 다음 TODO를 봐줘."
```
- 장점: clean slate, 토큰 0. SessionStart 훅이 핵심 맥락 재주입
- 단점: 어제의 세세한 논의는 git log + commit msg로 재구성해야 함 (commit message 잘 쓰면 OK)

### 옵션 C — /compact 후 이어하기 (이미 열려있는 세션)
```
/compact
```
- 현재 대화 요약 압축, PostCompact 훅이 AGENTS + wiki 재주입
- 장점: 세션 유지하며 토큰 감량
- 단점: 세세한 nuance 손실

---

## 5. curator에게 "이거 반영해줘" 전달 패턴

child 작업 후 curator에게 리포트할 때 쓸 수 있는 프롬프트:

```
tmux 3번창에서 ~/robot/datafactory에서 XXX 작업했어 (commit SHA abc123).
git log랑 diff 확인해서 parent 정책/wiki에 반영할 거 있으면 의논하자.
```

curator가 할 일:
1. `git -C ~/robot/datafactory log --oneline -5`
2. `git -C ~/robot/datafactory show abc123`
3. 필요 시 `~/robot/scripts/promote.sh <file>` 권고
4. `~/robot/wiki/` 또는 `~/robot/AGENTS.md` 업데이트 제안 → 네 승인 후 commit

### 자동화 (앞으로 도입 예정 — event hook system)
git post-commit 훅으로 자동 이벤트 주입 (설계는 `.omc/specs/deep-interview-event-propagation-*.md` 예정).

---

## 6. 토큰 비상 상황 대처

### 증상: 대화 느려짐, context 80%+ 사용
| 조치 | 명령 | 손실 |
|---|---|---|
| **요약 압축** | `/compact` | 대화 nuance 약간 |
| **대화 초기화** | `/clear` | 현재 세션 대화 전부. state 디스크 유지 |
| **새 세션 시작** | `claude` (아니면 `claude --continue`) | 세션 연속성 |
| **이어하기** | `claude --continue` | cwd별 최근 대화만 |

**가장 안전한 복구**: git log + .omc/specs|plans|research|state 읽으면 모든 설계 의도 복원됨. commit message가 "왜" 중심이면 OK.

---

## 7. 다중 child 병렬 작업 시 tmux 운영

```bash
# tmux 내부에서
tmux new-window -n datafactory -c ~/robot/datafactory
tmux new-window -n newchild -c ~/robot/newchild
tmux new-window -n curator -c ~/robot

# 창 전환
Ctrl+b 1  → curator
Ctrl+b 2  → datafactory
Ctrl+b 3  → newchild

# 각 창에서 claude 띄우면 독립 세션, 독립 MCP 로드
```

curator 창에서는 **절대 child MCP 사용 안 됨** (~/robot/에 .mcp.json 없으므로). child 창에서만 isaac-sim/ros-mcp 활성.

---

## 8. 긴급: curator 찾기 실패 시

"어제 curator 세션 어디 갔지?" 상황:

```bash
# 1. tmux 서버 확인
tmux ls                                       # 세션 있는지

# 2. Claude 프로젝트 기록 확인
ls ~/.claude/projects/-home-codelab-robot/    # robot 프로젝트 대화 기록

# 3. 최근 대화 이어열기
cd ~/robot && claude --continue

# 4. 그것도 없으면 완전 fresh
cd ~/robot && claude
# SessionStart 훅이 INDEX.md + AGENTS.md 주입 → "지난 커밋 log 확인해줘" 로 시작
```

---

## 9. 커밋 메시지 작성 원칙 (curator가 다음날 복원할 수 있도록)

### 좋은 예
```
docs(wiki): promote isaac_api_patterns to global

from: ~/robot/datafactory/wiki/lessons_isaac_sim.md
to:   ~/robot/wiki/isaac_sim_api_patterns.md
reason: 2nd child (teleop-prototype) began hitting same 4.2→4.5 migration
trigger: promote.sh checklist 3/5 (reproducible abstract pattern, 2+ children, repeat)
```

### 나쁜 예
```
update wiki
```

**"왜"가 메시지에 있으면 curator가 다음날도 맥락 복원 가능.**

---

## 10. Cheat Sheet (한눈에)

| 상황 | 명령 |
|---|---|
| 오늘 curator 시작 | `cd ~/robot && claude` |
| 컴퓨터 슬립 후 복귀 | `tmux a` |
| 다음날 이어하기 | `cd ~/robot && claude --continue` |
| 토큰 부담 | `/compact` → 훅 재주입으로 핵심 유지 |
| 대화만 리셋 | `/clear` → state 유지 |
| 세션 detach | `Ctrl+b d` |
| 창 전환 | `Ctrl+b <숫자>` |
| 새 창 같은 cwd | `Ctrl+b c` |
| 창 이름 변경 | `Ctrl+b ,` |
| curator 초기화 복구 | `cd ~/robot && claude` → INDEX.md 자동 로드 |

---

## 11. 관련 문서

- [`KEYBINDINGS.md`](KEYBINDINGS.md) — tmux/Claude/OMC 단축키 전체
- [`AGENTS.md`](AGENTS.md) — robot 레포 구조 + child 목록
- [`wiki/INDEX.md`](wiki/INDEX.md) — Global wiki (SessionStart 자동 로드)
- [`README.md`](README.md) — 레포 전체 사용법
