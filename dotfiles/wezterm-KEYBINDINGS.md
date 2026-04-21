# 단축키 가이드 (WezTerm + tmux)

> 이 패널 열기: `Ctrl+Shift+?` · 닫기: `Ctrl+Shift+X` · 스크롤: 휠/방향키 · 종료: `q`
>
> **두 레이어가 공존**: WezTerm = 외부 터미널 (탭/창/워크스페이스), tmux = 내부 세션 (prefix 기반). 구분 규칙: WezTerm 키는 대부분 `Ctrl+Shift+*`, tmux는 `prefix + *` (prefix = `Ctrl+b`).

---

## 🪟 WezTerm (외부 터미널)

### 탭 & 창
| 키 | 동작 |
|---|---|
| `Ctrl+Shift+T` | 새 탭 (현재 cwd 유지) |
| `Ctrl+Shift+W` | 현재 탭 닫기 |
| `Ctrl+Shift+←` / `→` | 탭 순환 |
| `Ctrl+Shift+1`…`9` | N번 탭 바로가기 |
| `Ctrl+Shift+F` | 전체화면 토글 |

### 패널 (WezTerm-native, tmux 팬과 별개)
| 키 | 동작 |
|---|---|
| `Ctrl+Shift+\` | 좌우 분할 (cwd 유지) |
| `Ctrl+Shift+-` | 상하 분할 (cwd 유지) |
| `Ctrl+Shift+H/J/K/L` | 패널 포커스 이동 (Vim 방향) |
| `Ctrl+Shift+Alt+H/J/K/L` | 패널 크기 조절 |
| `Ctrl+Shift+X` | 현재 패널 닫기 |
| `Ctrl+Shift+Z` | 패널 zoom 토글 |

### 워크스페이스 (프로젝트별 탭 묶음)
| 키 | 동작 |
|---|---|
| `Ctrl+Shift+S` | 워크스페이스 목록 & 전환 |
| `Ctrl+Shift+N` | 새 워크스페이스 |
| `Ctrl+Shift+R` | 현재 워크스페이스 이름 변경 |
| `Ctrl+Shift+D` | 현재 워크스페이스 삭제 (마지막 1개는 불가) |

### 프로젝트
| 키 | 동작 |
|---|---|
| `Ctrl+Shift+P` | 프로젝트 선택기 (`~/robot/*/` child 스캔, parent 포함) |

### 복사 / 붙여넣기 / 폰트 / 검색
| 키 | 동작 |
|---|---|
| `Ctrl+Shift+C` | 복사 |
| `Ctrl+Shift+V` | 붙여넣기 |
| 마우스 드래그 | 선택 → 자동 복사 (ClipboardAndPrimary) |
| 마우스 우클릭 | 붙여넣기 |
| 마우스 가운데 클릭 | primary selection 붙여넣기 (Linux) |
| `Ctrl+Shift+Space` | Quick Select (화면 내 path/URL 키보드 선택) |
| `Ctrl+=` / `Ctrl+-` / `Ctrl+0` | 폰트 크기 +/-/reset |

---

## 🔀 tmux (내부 멀티플렉서, prefix = `Ctrl+b`)

> 모든 명령은 **먼저 `Ctrl+b` → 다음 키** 순서.

### 팬 분할 (IBus 한글 회피 바인딩)
| 키 | 동작 |
|---|---|
| `prefix + \` | **세로 분할** (Shift 없는 `\` — IBus 한글에서 `prefix + \|` 깨짐 회피) |
| `prefix + -` | 가로 분할 |
| `prefix + x` | 팬 닫기 (확인) |
| `prefix + z` | 팬 zoom 토글 |
| `prefix + {` / `}` | 팬 위치 스왑 |
| `prefix + space` | 레이아웃 순환 |
| `prefix + ←/→/↑/↓` | 팬 포커스 이동 |

### 창 (window)
| 키 | 동작 |
|---|---|
| `prefix + c` | 새 창 (cwd 유지) |
| `prefix + n` / `p` | 다음 / 이전 창 |
| `prefix + 0`…`9` | N번 창 바로가기 |
| `prefix + ,` | 창 이름 변경 |
| `prefix + &` | 창 닫기 (확인) |
| `prefix + w` | 창 목록 |

### 세션
| 키 | 동작 |
|---|---|
| `prefix + d` | **detach** (컴퓨터 슬립 / SSH 끊김에도 세션 유지) |
| `prefix + s` | 세션 목록 |
| `prefix + $` | 세션 이름 변경 |
| 셸: `tmux a` | 마지막 세션 재접속 |
| 셸: `tmux ls` | 세션 목록 |

### 스크롤 / 복사 모드
| 키 | 동작 |
|---|---|
| `prefix + [` | copy-mode 진입 (스크롤·검색 가능) |
| copy-mode: 방향키 / `Space` / `Enter` | 선택 범위 지정 & 복사 |
| `Ctrl+End`, `End`, `q` | copy-mode 종료 + 맨 아래로 (custom bind) |
| 마우스 휠 | copy-mode 자동 진입 후 스크롤 |
| `prefix + ]` | 복사 버퍼 붙여넣기 |

### 기타
| 키 | 동작 |
|---|---|
| `prefix + r` | `~/.tmux.conf` 리로드 (상태 메시지) |
| `prefix + ?` | 전체 키바인딩 목록 (tmux 내장) |
| `prefix + t` | 큰 시계 |

---

## ⚠️ WezTerm vs tmux 공존 주의

| 상황 | 권장 |
|---|---|
| 단일 터미널 + 간단한 분할 | **WezTerm 팬** (`Ctrl+Shift+\`) — GUI 자연스러움 |
| 원격 SSH / 세션 유지 필요 | **tmux** (`prefix + \`) — 컴퓨터 슬립 / 연결 끊김에도 살아남음 |
| 한글 입력 + 분할 | **tmux `prefix + \`** (WezTerm `Ctrl+Shift+\`는 한글 IME에서 가끔 키 손실) |
| 드래그로 복사 | WezTerm이 처리 — tmux 안에서는 **Shift+드래그** (tmux mouse 우회) |
| 붙여넣기 | 어디서든 `Ctrl+Shift+V` 또는 우클릭 (WezTerm 레이어에서 처리) |

**두 레이어를 섞어 쓰면** — WezTerm 안에 tmux 세션을 띄우고 원격에서는 tmux만 쓰는 게 전형적 패턴.

---

## 🐧 터미널 기본 단축키 (리눅스 공통)

### 커서 이동 · 삭제
| 키 | 동작 |
|---|---|
| `Ctrl+A` / `Ctrl+E` | 줄 맨 앞 / 맨 뒤 |
| `Alt+←` / `Alt+→` | 단어 단위 이동 |
| `Ctrl+U` / `Ctrl+K` | 커서 앞 / 뒤 전부 삭제 |
| `Ctrl+W` / `Alt+D` | 커서 앞 / 뒤 단어 삭제 |

### 프로세스 제어
| 키 | 동작 |
|---|---|
| `Ctrl+C` | 현재 프로세스 강제 종료 (SIGINT) |
| `Ctrl+Z` | 일시 정지 (백그라운드) — `fg`로 복귀 |
| `Ctrl+D` | EOF / 터미널 종료 |
| `Ctrl+L` | 화면 지우기 (`clear`) |

### 히스토리
| 키 | 동작 |
|---|---|
| `↑` / `↓` | 이전 / 다음 명령 |
| `Ctrl+R` | 명령 히스토리 역방향 검색 |
| `Ctrl+G` | 검색 취소 |

---

## 🇰🇷 한글 IME 주의 (`use_ime=true`)

- `prefix + |` (Shift+`\`) 은 IBus 한글 모드에서 tmux가 수신하지 못할 수 있음 → **`prefix + \` (Shift 없이)** 로 바인딩됨
- 한글 → 영문 전환: `Shift+Space` 또는 `Hangul` 키
- `wezterm.lua`의 `config.use_ime = true` 필수 (dotfiles/에 이미 설정)

### 🆘 한글이 갑자기 안 될 때 (IBus 데몬 깨진 상태)

터미널에서 한 번 실행 후 WezTerm 재포커스:

```bash
ibus-daemon --daemonize --xim --replace
```

- 환경변수 + `use_ime=true` 다 맞는데 한글 안 뜨면 데몬 깨진 것
- `~/.xprofile` 의 `export GTK_IM_MODULE=ibus / QT_IM_MODULE=ibus / XMODIFIERS=@im=ibus` 전제 (dotfiles/에 포함)
- 로그아웃/재로그인 없이 핫 복구 가능
- 자세한 원인/해결: `~/robot/wiki/lessons_environment.md`

---

## 📚 자세한 내용

- WezTerm + tmux 트러블슈팅: `~/robot/wiki/lessons_tmux_wezterm.md`
- robot 레포 통합 키바인딩 (OMC slash 명령 등 포함): `~/robot/KEYBINDINGS.md`
