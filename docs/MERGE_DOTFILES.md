# Merge dotfiles — 기존 설정과 통합하기

install.sh의 기본 정책: **backup → symlink**. 기존 `~/.config/wezterm/wezterm.lua` 등을 `<file>.pre-robot.<timestamp>.bak`로 이동 후 repo 버전으로 심링크.

이 문서는 **기존 설정 중 지키고 싶은 부분이 있을 때** 사용하는 대화형·수동 병합 절차입니다.

## 관리 대상 dotfiles

| Source (repo) | Target (HOME) |
|---|---|
| `dotfiles/wezterm.lua` | `~/.config/wezterm/wezterm.lua` |
| `dotfiles/wezterm-KEYBINDINGS.md` | `~/.config/wezterm/KEYBINDINGS.md` |
| `dotfiles/tmux.conf` | `~/.tmux.conf` |
| `dotfiles/xprofile` | `~/.xprofile` |

## Option A — `merge-dotfiles.sh` 대화형

```bash
./scripts/merge-dotfiles.sh                # 모든 파일 하나씩 선택
./scripts/merge-dotfiles.sh --file=wezterm # 하나만
./scripts/merge-dotfiles.sh --dry-run      # 동작만 출력, 쓰기 0
```

각 파일마다 선택:

- **[k]eep existing** — 기존 파일 그대로. repo 버전 사용 안 함 (해당 파일은 distribution에서 분리된 상태 유지).
- **[r]eplace** — `<file>.pre-robot.<ts>.bak`로 백업 후 repo 심링크. (install.sh --step=dotfiles와 동일 효과).
- **[m]erge manually** — `$EDITOR` (기본 `vi`)를 열고 diff 제공. 편집 종료 후 [r]로 재실행 또는 수동 완료.
- **[d]iff** — 차이를 보고 다시 물음.
- **[s]kip** — 이번 실행에서만 건너뜀.

## Option B — 수동 diff + 발췌

```bash
# 차이 확인
diff -u ~/.tmux.conf dotfiles/tmux.conf

# 수동 편집 — 기존 설정에 repo 것 중 원하는 부분만 추가
$EDITOR ~/.tmux.conf

# 통합 후 doctor.sh 는 "not symlinked to repo" WARN — 의도된 상태.
# 완전히 repo 버전으로 가려면 백업 후 심링크:
mv ~/.tmux.conf ~/.tmux.conf.manual.bak
ln -s $(realpath dotfiles/tmux.conf) ~/.tmux.conf
```

## Option C — 사용자 override 레이어 (future)

현재 distribution은 override loader를 포함하지 않음. 수요 발생 시 도입 계획:

```lua
-- dotfiles/wezterm.lua 말미 (제안)
pcall(require, 'robot.override')
```

override 파일 (사용자 관리):

```lua
-- ~/.config/wezterm/robot/override.lua
local config = ...   -- wezterm이 넘겨주는 config
config.font_size = 16  -- 개인 preference
return config
```

(구현 시 이 섹션 업데이트)

## 주의사항

- **기존 dotfile이 `.bak` 백업 없이 덮어쓰이지 않도록 보장** — install.sh/merge-dotfiles.sh 모두 timestamped 백업 생성. 문제 발생 시 `~/.*.pre-robot.*.bak` 복원.
- **심링크 타겟이 repo를 벗어나면 주의** — `readlink ~/.tmux.conf` 가 repo `dotfiles/` 바깥을 가리키면 install.sh --step=dotfiles 재실행 시 AGAIN 백업 시도 가능.
- **tmux 3.2+ 바인딩** — repo tmux.conf의 `bind '\\'` 세로 분할은 IBus 한글 모드 + WezTerm use_ime 조합의 lesson (참조: `wiki/lessons_tmux_wezterm.md`). 무심코 교체 시 한글 모드에서 깨질 수 있음.
- **WezTerm IME** — `config.use_ime = true`는 한글 입력 필수. repo 버전에 포함.

## 관련

- `dotfiles/README.md` — 심링크 매핑 테이블 + 롤백 절차
- `docs/INSTALL.md` §dotfiles 레이어 — install.sh 측 backup 정책
- parent `wiki/lessons_tmux_wezterm.md` (참조 가능 시) — tmux/WezTerm IME 교훈 이력
