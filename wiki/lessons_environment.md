---
type: lesson
title: 환경 세팅 교훈
date: 2026-04-17
---

# 환경 세팅 교훈

## jq 미설치 → statusline [] 공백
- **증상:** Claude Code 상태표시줄 모델명이 `[]`로 표시
- **원인:** `jq`가 없으면 파싱 실패 → `2>/dev/null`로 에러 억제 → 빈 문자열
- **해결:** `sudo apt-get install -y jq`

## 한국어 입력 재부팅 후 깨짐
- **원인 1:** IBus 환경변수를 `.bashrc`에 넣으면 X11 세션 시작 후 로드 → WezTerm이 먼저 뜨면 못 받음
- **해결 1:** `~/.xprofile`에 넣어야 X11 세션 시작 시 자동 적용
```bash
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
```
(- **원인 2:** WezTerm 기본값은 IME 비활성화 → 환경변수가 있어도 입력 안 됨
- **해결 2:** `~/.config/wezterm/wezterm.lua`에 `config.use_ime = true` 추가,이미함)
- **원인 3:** IBus 데몬이 깨진 상태 → use_ime 추가 후에도 안 될 수 있음
- **해결 3:** `ibus-daemon --daemonize --xim --replace` 로 데몬 강제 재시작(바로시도)

## xhost +local:docker 자동화
- 매 세션마다 수동으로 치지 않으려면 `~/.xprofile`에 추가
```bash
xhost +local:docker &>/dev/null
```

## Nerd Font 설치 시 디렉토리 선생성 필요
- `unzip`이 디렉토리 없으면 실패
- 반드시 `mkdir -p ~/.local/share/fonts/폴더명` 먼저
