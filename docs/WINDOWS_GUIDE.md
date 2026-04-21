# Windows 사용자 가이드 (out-of-scope, WSL2 포인터)

**이 distribution은 Windows 네이티브를 지원하지 않습니다.** Ubuntu 22.04 strict. Windows 사용자가 시도할 수 있는 옵션:

## WSL2 (권장)

[공식 WSL2 설치](https://learn.microsoft.com/en-us/windows/wsl/install).

```powershell
wsl --install -d Ubuntu-22.04
```

Ubuntu 22.04 진입 후 이 distribution을 정상 설치 가능. 단:

### GPU passthrough 주의

- Windows 11 + 최신 NVIDIA 드라이버 + WSL2 → NVIDIA CUDA on WSL2 지원.
- Windows 10은 미검증.
- `nvidia-smi` WSL2 내에서 실행 → 드라이버 버전 호환성 확인.
- **NVIDIA Container Toolkit은 WSL2 모드에서 몇 가지 제약** — Isaac Sim GUI 컨테이너 X11 전달 복잡.
- Isaac Sim 사용은 **Ubuntu 네이티브 권장**. ROS2만이면 WSL2에서 대부분 작동.

### WSL2 제약 요약

- `systemd` 기본 비활성 (WSL 0.67+부터 활성화 가능 — `/etc/wsl.conf`)
- Docker Desktop for Windows와 `nvidia` runtime 호환 패턴 상이 → Ubuntu 네이티브 대비 검증 범위 좁음
- 호스트 Windows의 `\\wsl$\...` 경로로 cross-access 가능하나 심볼릭 링크·권한 모델 차이

### WSL2에서 시도 순서

```bash
# Ubuntu 22.04 WSL 진입
cd ~ && git clone --recurse-submodules https://github.com/hasemu1211/robot
cd robot
./scripts/install.sh --dry-run --force-os    # 먼저 계획 확인
./scripts/install.sh --force-os              # 실제 (24.04 warn 대응 + WSL 특성)
./scripts/doctor.sh                           # 각 layer 상태
```

`host.nvidia` 체크는 WSL2 GPU가 노출되면 통과. 실패 시 Windows 측 드라이버 업데이트.

## 대안

- **Hyper-V / VMware / VirtualBox**: Ubuntu 22.04 VM + NVIDIA GPU passthrough (IOMMU 지원 CPU + 디바이스 분리 필요)
- **전용 Linux 머신**: 가장 간단. 듀얼 부트 포함.
- **클라우드**: Paperspace/Lambda/RunPod 등 NVIDIA GPU 인스턴스 임대 + Ubuntu 22.04 선택

## 지원 범위 및 기여 요청

**이 distribution은 Windows 사용자를 지원 대상에서 제외합니다.** WSL2 작동 보고는 `docs/VERIFIED.md` 에 PR 환영. install.sh 경로에서 Windows-specific 코드 추가는 기여 정책상 받지 않습니다 (스코프 inflation 방지).
