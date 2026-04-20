# Isaac Sim API 패턴 (4.5.0)

> DATAFACTORY에서 축적된 Isaac Sim 관련 크로스-프로젝트 지식. 버전: 4.5.0 (RTX 5060 Blackwell 환경).

## 4.2.0 → 4.5.0 API 경로 마이그레이션 (필수)

```python
# 구 API (사용 금지 — 4.2.0)
from omni.isaac.nucleus import get_assets_root_path
from omni.isaac.core.prims import XFormPrim
from omni.isaac.core import World
from omni.isaac.core.utils.prims import create_prim
from omni.isaac.core.utils.stage import add_reference_to_stage

# 신 API (4.5.0 — 반드시 사용)
from isaacsim.core.utils.nucleus import get_assets_root_path
from isaacsim.core.prims import XFormPrim             # ← core.prims (api.prims 아님)
from isaacsim.core.api import World
from isaacsim.core.utils.prims import create_prim
from isaacsim.core.utils.stage import add_reference_to_stage
```

**주의:** `isaacsim.core.api.prims`는 존재하지 않음. `isaacsim.core.prims`가 올바른 경로.

## Kit Extension 로딩 — registry 우회만 성공

| 방법 | 결과 | 원인 |
|---|---|---|
| `--enable <name>` | exit 55 | registry 조회 |
| `[dependencies] "name" = {}` | exit 55 | registry 조회 |
| `[settings.exts."name"].enabled = true` | silent 실패 | extension 자체 설정 네임스페이스 |
| `--exec enable_mcp.py` + `manager.set_extension_enabled()` | **성공** | registry 완전 우회 |

**권장 패턴 (enable_mcp.py):**
```python
import omni.kit.app
manager = omni.kit.app.get_app().get_extension_manager()
if not manager.is_extension_enabled("isaac_sim_mcp_extension"):
    manager.set_extension_enabled("isaac_sim_mcp_extension", True)
```

## Extension 발견 — /isaac-sim/exts/ 심링크

`/isaac-sim/exts/`는 Kit 기본 스캔 폴더. 컨테이너 entrypoint에서 직접 심링크 생성:

```bash
ln -sfn /opt/isaac-sim-mcp/isaac.sim.mcp_extension /isaac-sim/exts/isaac_sim_mcp_extension
```

호스트 bind mount의 심링크는 Kit이 따라가지 않을 수 있음 → **컨테이너 내부에서 직접 생성**.

## Docker ENTRYPOINT 오버라이드 필수

```yaml
isaac-sim-streaming:
  image: nvcr.io/nvidia/isaac-sim:4.5.0
  entrypoint: ["/bin/sh", "/entrypoint-mcp.sh"]
  command: []
```

기본 ENTRYPOINT는 `runheadless.sh`로 고정. 커스텀 kit 사용 시 `license.sh` + `privacy.sh` 수동 호출 필요.

## WebRTC 스트리밍 (GUI 접근 유일 경로)

- **포트 49100**: WebRTC 시그널링 (WebSocket) — HTTP 아님, 브라우저 직접 접속 불가
- **포트 8766**: MCP extension TCP 소켓
- Isaac Sim **WebRTC Streaming Client** (standalone AppImage) 필요
  - 다운로드: https://github.com/isaac-sim/IsaacSim-WebRTC-Streaming-Client/releases
  - Ubuntu 22.04+ FUSE 2 필수: `sudo apt-get install libfuse2`
  - 실행 후 `127.0.0.1` → Connect

## RTX 5060 (sm_120 Blackwell) 호환성

- **iray photoreal 렌더러**: 미지원 (경고 출력되나 무시 가능) — Isaac Sim 4.5.0이 RTX 5060 출시 전 릴리즈
- **Omniverse RTX Renderer** (합성 데이터 생성용): 정상 동작
- 합성 데이터 생성(SDG)은 iray가 아닌 RTX Renderer 기반이므로 프로젝트 영향 없음

## 무시 가능한 경고 패턴

| 메시지 | 원인 | 영향 |
|---|---|---|
| `omni.anim.navigation.recast` v2.3 vs v3.2 | Isaac Sim 내부 버전 불일치 | 없음 |
| `OmniHub is inaccessible` | NVIDIA 클라우드 미연결 | 없음 |
| `IOMMU is enabled` | 커널 설정 | 없음 |
| `iray photoreal` GPU 미지원 | RTX 5060 호환성 | 없음 |
