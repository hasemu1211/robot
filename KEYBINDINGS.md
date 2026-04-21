# KEYBINDINGS — robot 개발환경 단축키 정리

> tmux + Claude Code + OMC + robot scripts 통합. 이 파일은 `~/robot/` 루트에 있지만, 키 변경이 생기면 여기를 업데이트하세요.
>
> **WezTerm 단축키는 [`~/.config/wezterm/KEYBINDINGS.md`](../.config/wezterm/KEYBINDINGS.md)를 참조하세요.** WezTerm 내부에서 `Ctrl+Shift+?`를 누르면 해당 파일이 오버레이로 뜹니다. `wezterm-keybindings-sync` 스킬이 `wezterm.lua` 변경 시 해당 파일을 자동 갱신합니다 (이 파일은 건드리지 않음).

---

## 1. WezTerm — 외부 파일로 이관 (중복 제거)

**전체 목록**: `~/.config/wezterm/KEYBINDINGS.md` (`Ctrl+Shift+?`로 팝업).
**관리 주체**: `wezterm-keybindings-sync` 스킬이 `wezterm.lua` → md 싱크 담당.
**이 파일에서 기억할 핵심만** (자주 잊는 것):

| 키 | 동작 | 메모 |
|---|---|---|
| `Ctrl+Shift+?` | WezTerm 키 오버레이 열기 | 전체 참조 |
| `Ctrl+Shift+P` | 프로젝트 picker (`~/robot/*` 스캔, robot parent도 선택지) | bootstrap-child.sh 등록된 child 자동 등장 |
| `Ctrl+Shift+S` | 워크스페이스 목록/전환 | 프로젝트별 탭 묶음 |
| `Ctrl+Shift+N` | 새 워크스페이스 | 새 robot child 작업용 |

---

## 2. tmux (세션·창·팬)

**Prefix**: `Ctrl+b` (tmux 기본). 아래 모든 명령은 prefix 먼저 누르고 키 입력.

### 팬 분할 (wezterm + IBus 환경 회피)
| 키 | 동작 |
|---|---|
| `prefix + \` | 세로 분할 (Shift 없음 — `prefix + |`는 한글 IME에서 깨짐) |
| `prefix + -` | 가로 분할 |
| `prefix + x` | 현재 팬 닫기 (확인) |
| `prefix + z` | 팬 zoom 토글 (현재 팬을 창 전체로 확대/축소) |
| `prefix + ←/→/↑/↓` | 포커스 이동 |
| `prefix + {/}` | 팬 위치 스왑 |
| `prefix + 공백` | 팬 레이아웃 순환 |

### 창 (window)
| 키 | 동작 |
|---|---|
| `prefix + c` | 새 창 |
| `prefix + n` / `p` | 다음/이전 창 |
| `prefix + <숫자>` | N번 창 바로가기 |
| `prefix + ,` | 현재 창 이름 변경 |
| `prefix + &` | 현재 창 닫기 (확인) |
| `prefix + w` | 창 목록 |

### 세션 (session)
| 키 | 동작 |
|---|---|
| `prefix + d` | **detach** (세션 유지한 채 빠져나옴) |
| `prefix + s` | 세션 목록 |
| `prefix + $` | 세션 이름 변경 |

### 스크롤 / 복사 모드
| 키 | 동작 |
|---|---|
| `prefix + [` | 스크롤(copy) 모드 진입 |
| `Ctrl+End` / `End` / `q` | 스크롤 모드 종료 + 맨 아래로 (custom bind) |
| 휠 스크롤 | mouse on 상태, 자동 copy 모드 진입 후 스크롤 |
| `prefix + ]` | 복사 버퍼 붙여넣기 |

### 기타
| 키 | 동작 |
|---|---|
| `prefix + r` | `~/.tmux.conf` 리로드 (display message 표시) |
| `prefix + ?` | 전체 키바인딩 목록 |

---

## 3. Claude Code

| 키 | 동작 |
|---|---|
| `/` (입력창 첫 글자) | slash command 자동완성 (skills, 빌트인) |
| `!` (입력창 첫 글자) | shell 명령 세션 내 실행 |
| `@<path>` | 파일 참조 자동완성 |
| `?` | 도움말 |
| `Esc` | 현재 agent 턴 취소 |
| `Shift+Tab` | 모드 전환 (ask → auto-edit → plan 등) |
| `Ctrl+C` | 현재 작업 중단 |
| `Ctrl+D` | 세션 종료 |
| `claude --continue` | 이 프로젝트의 최신 대화 이어 열기 (**다음날 재시작 시 필수**) |
| `/clear` | 현재 대화 초기화 (state 디스크 유지) |
| `/compact` | 대화 요약 압축 (PostCompact 훅이 AGENTS.md+wiki 재주입) |
| `/model` | 모델 전환 (opus/sonnet/haiku) |
| `/help` | 공식 도움말 |

---

## 4. OMC (텍스트 트리거 / slash)

대부분 slash 명령. 자주 쓰는 것만.

| 명령 | 용도 |
|---|---|
| `/oh-my-claudecode:deep-interview` | Socratic 요구사항 인터뷰 |
| `/oh-my-claudecode:plan --consensus` | Ralplan (Planner/Architect/Critic) |
| `/oh-my-claudecode:autopilot` | 계획 기반 자율 실행 |
| `/oh-my-claudecode:ralph` | Persistence loop (acceptance까지 자율 반복) |
| `/oh-my-claudecode:team` | N명 tmux teammate 병렬 (teammateMode=tmux 필요) |
| `/oh-my-claudecode:wiki` | 현재 cwd의 `wiki/` 읽기/쓰기 |
| `/oh-my-claudecode:deepinit` | 계층적 AGENTS.md 자동 생성 |
| `/oh-my-claudecode:mcp-setup` | MCP 서버 프로젝트별 격리 마법사 |
| `/oh-my-claudecode:remember` | 재사용 지식 분류 (project-memory / notepad / durable) |
| `/oh-my-claudecode:skillify` | 반복 워크플로우 → skill 증류 |
| `/oh-my-claudecode:learner` | 현재 세션에서 learned skill 추출 |
| `/oh-my-claudecode:external-context` | document-specialist 병렬 조사 |
| `/oh-my-claudecode:cancel` | autopilot/ralph 등 실행 모드 중단 |
| `/oh-my-claudecode:verify` | 완료 주장 검증 (evidence-based) |

### 키워드 트리거 (프롬프트에 포함하면 자동 라우팅)
- `autopilot` / `ulw` (ultrawork) / `ralph` / `ccg` / `ralplan` / `cancelomc` / `tdd` / `ultrathink` / `deepsearch`

---

## 5. robot 레포 전용 명령

| 명령 | 용도 |
|---|---|
| `~/robot/scripts/bootstrap-child.sh <name>` | 새 child 생성 |
| `~/robot/scripts/bootstrap-child.sh <abs-path>` | 기존 레포를 symlink child로 등록 |
| `~/robot/scripts/bootstrap-child.sh --dry-run` | 실행 없이 계획만 출력 |
| `~/robot/scripts/promote.sh <child>/<file>` | child → parent wiki 승격 (pre-flight scan 포함) |
| `~/robot/scripts/promote.sh --dry-run` | 승격 계획만 |

---

## 6. 환경 주의사항 (세션 생존 & 한글 IME)

### tmux session 생존
- **SSH/wezterm 닫기**: 세션 유지 ✅ (`tmux attach`로 복귀)
- **Suspend/Hibernate**: 유지 ✅ (컴퓨터 슬립 상태에서 tmux+claude 그대로)
- **Shutdown/Reboot**: **세션 사망** ❌ — tmux 서버가 커널과 함께 죽음
- → 다음날 이어하려면 **슬립** 권장, 불가피하면 `cd ~/robot/<child> && claude --continue`

### WezTerm + IBus 한글 주의
- `use_ime=true`로 한글 입력 OK
- 한글 모드에서 `prefix + |` 전송이 깨질 수 있어 → `prefix + \` 로 바인딩
- wezterm `config.mouse_bindings`에 항목 지정 시 **기본 바인딩 덮어쓰기** 주의 — `CompleteSelection 'ClipboardAndPrimarySelection'` 명시 필요

### Claude Code 세션 복원 ("이어하기")
```bash
cd ~/robot/<child>             # 또는 ~/robot/ (parent)
claude --continue              # 최근 대화 이어 열기 (해당 cwd 기준)
```

- 단, `--continue`는 **같은 cwd**의 최근 대화만 복구. 다른 cwd로 이동하면 해당 cwd의 대화가 복구됨.
- 완전히 새로 시작하려면 그냥 `claude`.
- Claude Code의 "프로젝트"는 cwd 해시 기반 (`~/.claude/projects/<hash>/`).

---

## 업데이트 정책

- tmux/wezterm 키 변경 시 → 즉시 이 파일 갱신 + `git commit`
- OMC 버전 업데이트 후 새 명령 생기면 추가
- 깊은 트러블슈팅은 `wiki/lessons_tmux_wezterm.md` (child) 또는 `wiki/omc_workflows.md` (parent)
