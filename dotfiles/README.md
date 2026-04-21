# robot / dotfiles

`install.sh --step=dotfiles`가 이 디렉토리의 파일들을 사용자 HOME 경로에 **심링크**로 배치합니다.
기존 파일이 있으면 `<file>.pre-robot.<timestamp>.bak`로 백업 후 교체 (AC-1e).

## 심링크 매핑

| Source (이 repo) | Target (사용자 HOME) | 목적 |
|---|---|---|
| `dotfiles/wezterm.lua` | `~/.config/wezterm/wezterm.lua` | WezTerm 설정 — use_ime=true, Tokyo Night, JetBrainsMono Nerd Font, 탭/패널 키바인딩, 프로젝트 선택기 |
| `dotfiles/wezterm-KEYBINDINGS.md` | `~/.config/wezterm/KEYBINDINGS.md` | WezTerm 내 `Ctrl+Shift+?` 팝업용 간략 키바인딩 (wezterm.lua line 302에서 참조) |
| `dotfiles/tmux.conf` | `~/.tmux.conf` | tmux 3.2+ 설정 — mouse on, 256color, `prefix + \` 세로 분할 (IBus 한글 모드 회피, lesson f) |
| `dotfiles/xprofile` | `~/.xprofile` | IBus 환경변수 + Isaac Sim 컨테이너용 `xhost +local:docker` |

## 기존 파일 정책

- **기본 (backup → symlink)**: `install.sh --step=dotfiles`가 기존 파일을 `<file>.pre-robot.<UTC timestamp>.bak`로 이동 후 symlink 생성.
- **대화형 병합**: `scripts/merge-dotfiles.sh` 실행 — 파일마다 `[k]eep existing / [r]eplace / [m]erge manually ($EDITOR diff) / [s]kip` 선택.
- **수동**: 사용자가 직접 `diff dotfiles/foo ~/foo`로 비교 후 원하는 부분만 발췌 병합.

## 롤백

```bash
# install.sh 취소: 백업 파일을 제자리로 복원
for f in ~/.config/wezterm/wezterm.lua.pre-robot.*.bak ~/.tmux.conf.pre-robot.*.bak ~/.xprofile.pre-robot.*.bak; do
  [ -f "$f" ] && mv "$f" "${f%.pre-robot.*.bak}"
done
```

## 커스터마이징

**이 repo의 dotfiles를 직접 수정하지 마세요** (distribution 기본값) — fork 시 유지. 사용자별 override는:

1. `~/.config/wezterm/wezterm.robot.override.lua` 생성 (fork 독립). wezterm.lua 말미에 `pcall(require, 'wezterm.robot.override')` 추가 제안.
2. tmux/xprofile은 선행 load 후 `~/.tmux.local.conf` / `~/.xprofile.local` 에 override 작성.

(현재 distribution에는 override loader가 포함되지 않음 — 수요 발생 시 추가 예정.)

## 관련

- `docs/MERGE_DOTFILES.md` — `merge-dotfiles.sh` 상세 사용법
- parent `KEYBINDINGS.md` — wezterm + tmux 통합 키바인딩 reference (wezterm용 pop-up `wezterm-KEYBINDINGS.md`와 구분)
