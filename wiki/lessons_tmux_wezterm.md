# tmux + wezterm 셋업 교훈 (2026-04-20)

## 필수 설치 (쉽게 빠뜨림)
- **xclip + xsel** — wezterm X11 클립보드 연동. 미설치 시 드래그 복사/붙여넣기 무음 실패. `sudo apt install xclip xsel`
- **tmux 3.2+** — Ubuntu 기본 repo로 설치 OK
- `~/.tmux.conf` 없으면 **마우스 휠 스크롤 안됨**. 최소 설정:
  ```
  set -g mouse on
  set -g history-limit 50000
  set -g default-terminal "tmux-256color"
  set -ga terminal-overrides ",xterm-256color:RGB"
  set -s escape-time 0
  bind | split-window -h -c "#{pane_current_path}"
  bind - split-window -v -c "#{pane_current_path}"
  ```

## wezterm 마우스 바인딩 (드래그 복사)
- `config.mouse_bindings`에 항목을 지정하면 기본 바인딩이 덮어써질 수 있음
- 드래그 자동 복사를 원하면 명시적으로 추가:
  ```lua
  { event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection' }
  ```
- tmux 안에서 드래그는 tmux가 가로챔 → **Shift+드래그**로 우회 (단, 클립보드 붙여넣기 검증은 `xclip -selection clipboard -o`)

## 해결: tmux `prefix + |` 실패 → `bind '\'` 로 회피 (2026-04-20)

**원인 (최종 확인):**
- wezterm 키바인딩 선언은 **modifier 조합**을 명시하므로 `|` 를 얻으려면 `key = '|', mods = 'SHIFT'` 형식이 필수
- tmux `bind` 는 **송신된 문자 그대로**에 바인딩 — modifier 개념 없음 → `\` (Shift 없음)로 충분
- `bind |` 로 선언해 두면 Shift+\\ 조합이 실제로 `|` 문자로 전달돼야 작동. 이 환경(wezterm `use_ime=true` + IBus 한글)에서 Shift+\\ 전송이 깨지거나 modifier가 섞여 들어와 tmux가 `|` 로 인식 못함
- **해결**: `bind '\' split-window -h` 로 변경 — Shift 없는 평문 `\` 키 한 번에 매칭

**적용 후 동작 확인:**
- `prefix + \` (no Shift) → 세로 분할 정상
- `prefix + -` → 가로 분할 정상
- `prefix + d` → detach 정상

**부수 관찰 (원인 아님, 참고):**
- prefix 대기 중 마우스 이동 시 prefix 대기열 해제됨 → mouse mode 부작용
- 영문/한글 IBus 모드 무관하게 발생했음 (IME 차원 문제 아님)

**환경:**
- wezterm (`use_ime=true`, CSI-u/leader/key_tables 없음)
- tmux 3.2a on Ubuntu X11, `DISPLAY=:0`

**작성 시 문법 주의:**
- `bind \` ❌ — 행 연속 문자로 해석됨
- `bind '\'` ✅ 또는 `bind \\` ✅
- 주석에 "prefix + |" 표기 남기지 말 것 — 실제 바인딩은 `\` 임

## OMC 4.13.0 글로벌 설치 완료 (2026-04-20)
- `~/.claude/CLAUDE.md` (OMC:START/END 마커)
- `~/.claude/settings.json`: statusLine HUD, `teammateMode: tmux`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- `~/.claude/.omc-config.json`: `defaultExecutionMode: ultrawork`, team `{3 agents, claude provider}`
- `~/.claude/hud/omc-hud.mjs` (HUD 래퍼)
- `omc` CLI v4.13.0 전역 설치 (`npm install -g oh-my-claude-sisyphus`)
- GitHub star 완료
