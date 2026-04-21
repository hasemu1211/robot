# install.sh — layer-by-layer reference

`scripts/install.sh` 의 각 레이어, 플래그, 실패 복구 절차.

## 개요

```
install.sh
├── host       # apt + Docker + NVIDIA toolkit
├── dotfiles   # symlink wezterm/tmux/xprofile/wezterm-KEYBINDINGS
├── cli        # Node20+ / claude / omc / rtk
├── claude     # marker-inject CLAUDE.md + merge settings.json + commands symlink
├── vendor     # git submodule status check (vendor/isaac-sim-mcp, external/robotics-agent-skills)
└── child      # informational — bootstrap-child.sh 사용 방법 안내
```

각 레이어는 독립 idempotent. `--step=<layer>`로 단일 레이어만 실행 가능.

## 플래그

| Flag | 효과 |
|---|---|
| `--dry-run` | 모든 동작을 `would do X`로 출력, 파일 쓰기 0 |
| `--step=<name>` | 해당 레이어만 실행 (host\|dotfiles\|cli\|claude\|vendor\|child) |
| `--yes` | 확인 프롬프트 skip |
| `--env-from-shell` | `NGC_API_KEY` 등을 shell env에서 읽어 `.env.local` 생성 (interactive prompt skip) |
| `--resume` | 마지막 실패 레이어부터 재개. 성공한 레이어는 SKIP |
| `--force-os` | `lsb_release -c == jammy` 검증 bypass (Ubuntu 24.04 등) |
| `--override` | settings.json scalar merge 시 기존 값 덮어쓰기 (기본: 기존 유지) |

## Idempotency state

- `.omc/state/install/<layer>.done` — 성공 시 기록 (sha256 of inputs 포함)
- `.omc/state/install/<layer>.fail` — 실패 시 기록 (reason 포함)
- `.omc/state/install/.lock` — 동시 실행 방지 (`flock`)
- 모두 **gitignored** — `git clean -fdx` 후엔 전체 재설치.

## 로그

- `.omc/logs/install-<UTC_ISO_ts>.log` — 전체 출력 (stdout + stderr)
- `.omc/logs/settings-merge-<ts>.log` — settings.json merge diff

## 레이어별 상세

### host

- `lsb_release -c` == jammy 검증 (unless `--force-os`).
- `sudo -v` 한 번 + 백그라운드 keepalive (`trap`으로 EXIT 시 정리).
- apt install: `jq xclip xsel libfuse2 tmux`.
- Docker 저장소 등록 + `docker-ce docker-ce-cli containerd.io docker-compose-plugin`.
- NVIDIA Container Toolkit 저장소 등록 + `nvidia-ctk runtime configure --runtime=docker` + `systemctl restart docker`.
- 사용자 `docker` 그룹 등록 (재로그인 안내).

### dotfiles

- 각 `dotfiles/<file>` → 해당 `~/<target-path>` 심링크.
- 기존 파일이 있고 repo 심링크가 아니면 → `<file>.pre-robot.<UTC_ISO_ts>.bak`로 이동 후 심링크.
- 이미 올바른 심링크면 SKIP.
- 대상 디렉토리 없으면 `mkdir -p` (예: `~/.config/wezterm/`).

**대안**: `scripts/merge-dotfiles.sh` (대화형 per-file 선택).

### cli

- Node.js 20+ (NodeSource 20.x 저장소).
- `claude` (`@anthropic-ai/claude-code` npm global).
- OMC 플러그인 (`claude plugin install oh-my-claudecode`).
- `omc` npm (non-critical — 실패해도 warning).
- **rtk** (token-compressing Bash 훅) — `curl | sh` 설치 후 `rtk init -g --auto-patch`로 Claude Code 훅 등록.

### claude

3단계:

1. **E-0 pre-flight**: `~/.claude/CLAUDE.md` 파싱 (line-based state machine). 거부 조건:
   - 같은 토큰(`<!-- OMC:START -->` 등) 중복 등장
   - END가 START보다 앞
   - ROBOT 블록이 OMC 블록 내부 위치 (AC-7 위반)
   - unmatched 토큰

   거부 시 `.pre-robot.<ts>.bak` 백업 후 exit 2 + 본 문서 manual-recovery 섹션 안내.

2. **E-1 marker inject**: `claude/CLAUDE-marker.md`를 `~/.claude/CLAUDE.md` 에 삽입/교체.
   - 기존 `<!-- OMC:ROBOT:START -->` 블록 있으면 in-place 교체.
   - 없으면 OMC:END 다음 (또는 EOF) 에 append.
   - **반드시 OMC 블록 외부에** 위치.

3. **E-2 settings merge**: `claude/settings-seed.json`을 `~/.claude/settings.json`에 병합.
   - Arrays: **additive** (JSON-equal dedup via `jq --sort-keys`).
   - Scalars: **preserve-existing** (기존 값 우선). `--override`시만 덮어씀.
   - Type mismatch (user=array, seed=scalar 등): preserve user + WARN.
   - Invalid input JSON: abort + `.bak` 복원.
   - Diff 로그: `.omc/logs/settings-merge-<ts>.log`.

4. **commands symlink**: `claude/commands/*.md` → `~/.claude/commands/` 심링크 (개별 파일).

### vendor

- `vendor/isaac-sim-mcp/` submodule status (`.git/` pointer 존재, HEAD resolve).
- `external/robotics-agent-skills/` submodule status.
- **실제 fork URL 설정 + 패치 커밋은 B-1..B-7 (설계 문서 참조) — 현재는 설정 검증만**.

### child

정보 출력 (no-op 레이어). 사용자에게 `bootstrap-child.sh --profile=isaac+ros2 <name>` 실행 안내.

## 실패 복구

### 레이어 중간 실패

```bash
./scripts/install.sh              # 어떤 레이어에서 .fail 기록 + 로그 출력
tail -50 .omc/logs/install-*.log  # 원인 파악
# 근본 원인 수정
./scripts/install.sh --resume     # 실패 레이어부터 재개
```

### 완전 롤백 (dotfiles 복원)

```bash
# install.sh가 만든 심링크 제거 + 백업 복원
for bak in ~/.tmux.conf.pre-robot.*.bak \
           ~/.xprofile.pre-robot.*.bak \
           ~/.config/wezterm/wezterm.lua.pre-robot.*.bak \
           ~/.config/wezterm/KEYBINDINGS.md.pre-robot.*.bak; do
  [ -f "$bak" ] && mv "$bak" "${bak%.pre-robot.*.bak}"
done
# ~/.claude 마커 제거: 수동으로 <!-- OMC:ROBOT:START --> ... <!-- OMC:ROBOT:END --> 블록 삭제
# 또는 settings.json 백업 복원: mv ~/.claude/settings.json.pre-rtk.*.bak ~/.claude/settings.json
# idempotency state 초기화:
rm -rf .omc/state/install/
```

### manual-recovery (E-0 파싱 거부)

**상황**: `~/.claude/CLAUDE.md`에 `<!-- OMC:START -->` 블록이 존재하지만 형식이 예상과 다름 (예: 중복 토큰, END가 START보다 앞, ROBOT 블록이 OMC 블록 안에 잘못 삽입됨).

**복구 절차**:

1. `~/.claude/CLAUDE.md.pre-robot.<ts>.bak` 파일 확인 (install.sh가 자동 백업).
2. `~/.claude/CLAUDE.md` 수동 열고 다음 불변량 확인:
   - `<!-- OMC:START -->` 단 1회, `<!-- OMC:END -->` 단 1회.
   - `<!-- OMC:ROBOT:START -->` 단 1회 (또는 0회), `<!-- OMC:ROBOT:END -->` 단 1회 (또는 0회).
   - **ROBOT 블록은 OMC 블록 외부(뒤)에 위치** (AC-7).
3. 수정 후 `./scripts/install.sh --step=claude` 재실행.
4. 해결 불가 시 `.bak` 원본 복원 + `./scripts/install.sh --step=claude` (신규 CLAUDE.md로 간주).

## CI / 자동화

```bash
# 사전 조건
export NGC_API_KEY=xxx
./scripts/install.sh --yes --env-from-shell --force-os

# 검증
./scripts/doctor.sh --json | jq -e '.summary.fail == 0' || exit 1
```

## 관련

- `docs/HOST_PREREQUISITES.md` — 호스트 사전 준비
- `docs/MERGE_DOTFILES.md` — dotfiles 수동 병합
- `docs/ROBOTICS_SKILLS.md` — robotics-agent-skills 심링크 주입
- `scripts/doctor.sh --help`
