# Gemini Lessons — AI 에이전트의 로봇 조작 마스터리

> Gemini CLI가 이 환경에서 Isaac Sim 및 ROS2를 조작하며 얻은 기술적 교훈과 트러블슈팅 가이드.

## 1. MCP (Model Context Protocol) 통신 트릭

### 1.1 JSON-RPC Pydantic 검증 에러 방지
- **문제**: Pydantic은 표준 입력(stdin)으로 들어오는 멀티라인 JSON을 파싱할 때 `EOF while parsing` 에러를 낼 수 있음.
- **해결**: 모든 JSON 요청을 한 줄로 압축하여 전달하십시오.
  ```bash
  # 권장 패턴
  echo '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "get_scene_info", "arguments": {}}, "id": 1}' | uv run isaac_mcp/server.py
  ```

### 1.2 초기화 절차 (Initialization)
- MCP 서버는 연결 직후 `initialize` 요청을 기대함. 이를 건너뛰고 `tools/call`을 보내면 `Invalid request` 에러가 발생함.
- 정밀한 조작이 필요할 경우 `initialize` -> `initialized` 알림 -> `tools/call` 순서를 지키는 Python 스크립트를 즉석에서 작성하여 실행하십시오.

## 2. Isaac Sim 4.5.0 실전 조작

### 2.1 모듈 탐색 실패 대응
- 컨테이너 내부에서 `python.sh`로 스크립트 실행 시 `isaacsim.core`를 찾지 못하는 경우가 있음.
- 이 경우 `PYTHONPATH`에 `/isaac-sim/exts/isaacsim.core/` 등 익스텐션 경로를 명시적으로 추가하거나, MCP 서버 브릿지를 통한 조작을 우선순위에 두십시오.

### 2.2 RTX 5060 호환성
- RTX 5060(Blackwell) 환경에서 `iray` 렌더러 관련 경고는 무시 가능함. `Omniverse RTX Renderer`는 정상 작동하므로 합성 데이터 생성(SDG)에 지장 없음.

## 3. ROS2 브릿지 최적화

### 3.1 9090 Port 직접 접근
- `ros-mcp`를 통하는 것 외에도, `websockets` 라이브러리를 사용해 Python으로 직접 9090 포트에 접속하여 JSON 메시지를 주고받는 방식이 매우 빠르고 유연함.

---
**Last Updated: 2026-04-21 (Gemini CLI)**
