# Host Prerequisites

install.sh `host` 레이어가 설치하는 것 + 사용자가 **사전에** 준비해야 하는 것.

## 자동 설치 (install.sh --step=host)

- `jq`, `xclip`, `xsel`, `libfuse2`, `tmux` (3.2+)
- Docker Engine + `docker compose` plugin
- NVIDIA Container Toolkit (`nvidia-ctk`)
- (비필수) Docker 로그 용량 제한 설정

## 사전 준비 (사용자 책임)

### 1. NVIDIA 드라이버

```bash
nvidia-smi --version   # 설치 확인 (≥ 470)
```

미설치 시 Ubuntu 공식 가이드 참고. Desktop 환경 재부팅 필요 가능.

### 2. NGC (NVIDIA GPU Cloud) 계정 + 토큰

Isaac Sim 이미지 pull 필수:

1. [ngc.nvidia.com](https://ngc.nvidia.com) 가입 → API Key 생성.
2. `docker login nvcr.io`
   - Username: `$oauthtoken` (literal string)
   - Password: 생성된 API Key
3. `.env.local`에 `NGC_API_KEY=<your key>` 작성 또는 shell에 export (install.sh `--env-from-shell` 플래그 사용).

### 3. 사용자 그룹 (docker)

```bash
sudo usermod -aG docker $USER
# 재로그인 또는 `newgrp docker`
```

### 4. X11 + IBus (한국어 입력 + Isaac Sim GUI 컨테이너)

`~/.xprofile` (install.sh가 `dotfiles/xprofile`을 심링크) 에 이미 설정:

```bash
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
xhost +local:docker &>/dev/null
```

재로그인 후 반영.

### 5. WezTerm (권장 터미널)

[wezterm.org](https://wezterm.org) 공식 패키지. 한국어 입력은 `use_ime = true` (dotfiles/wezterm.lua에 이미 포함).

### 6. GPU 호환성

install.sh는 GPU tier를 강제하지 않음. doctor.sh가 다음 경고:

- Compute capability ≥ sm_86 (Ampere) 미만 → WARN (Isaac Sim 일부 기능 제한)
- VRAM < 8GB → WARN (Isaac Sim 권장 사양 미달)
- iray photoreal 경고는 Blackwell/Ada/일부 Ampere에서 정상 출력 — 무시 (RTX Renderer로 데이터 생성)

### 7. 디스크 여유

- Isaac Sim 이미지: ~15GB
- ROS2 Humble 이미지: ~750MB
- Isaac Sim 캐시 (`~/.cache/ov/`): ~10-30GB 누적 가능
- **최소 80GB 자유 공간 권장**

캐시 정리: child에 심링크된 `templates/scripts/clean_storage.sh` 사용.

## 한 줄 설치 (Ubuntu 22.04)

사용자 사전 준비 사항만:

```bash
# Node.js 20+ (NodeSource)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Claude Code CLI
npm install -g @anthropic-ai/claude-code

# WezTerm (권장)
curl -LO https://github.com/wezterm/wezterm/releases/latest/download/wezterm-nightly.Ubuntu22.04.deb
sudo apt install -y ./wezterm-nightly.Ubuntu22.04.deb
```

이후 `./scripts/install.sh`.

## 알려진 이슈

### Ubuntu 24.04

install.sh는 `lsb_release -c | grep -q jammy`를 검증. 24.04(`noble`)는 `--force-os`로 override 가능하나 다음 차이 주의:
- `libfuse2` → `libfuse2t64` (패키지명 변경)
- NVIDIA Container Toolkit 저장소 URL 동일
- Isaac Sim 4.5.0 이미지는 22.04 기반이라 호스트 OS 무관
- doctor.sh의 `libfuse2` 체크는 양쪽 패키지명 모두 수용

### Ubuntu ≤ 20.04

tmux < 3.2 → 바인딩 문법 차이. install.sh는 거부. 수동으로 tmux 빌드 또는 20.04 업그레이드 권장.

### Docker Desktop for Linux

이 distribution은 Docker Engine 기반 가정. Docker Desktop은 `nvidia` runtime 호환성이 달라 별도 검증 필요.

## IOMMU 경고

Isaac Sim 로그에 `IOMMU is enabled` 출력되어도 정상. 커널 설정이며 Isaac Sim 기능에 영향 없음.

## 관련 문서

- `docs/INSTALL.md` — install.sh 각 레이어 상세
- `docs/WINDOWS_GUIDE.md` — WSL2 가이드
- parent `wiki/isaac_sim_api_patterns.md` — Isaac Sim 4.5.0 API/RTX 5060 호환성
