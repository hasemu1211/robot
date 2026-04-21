# GEMINI.md — Gemini CLI Global Mandates (Robotics Distribution)

> 이 파일은 Gemini CLI가 이 로봇 개발 환경(Distribution)에서 활동할 때 준수해야 할 **최상위 지침서**입니다. 모든 기본 워크플로우보다 우선합니다.

## 1. 핵심 조작 원칙 (Core Operational Principles)

### 1.1 Isaac Sim 4.5.0 API 경로
- **절대 규칙**: `omni.isaac.*` 경로는 구버전(4.2.0 이하)용입니다. 4.5.0 환경에서는 반드시 **`isaacsim.core.*`** 경로를 사용하십시오.
  - 예: `from isaacsim.core.api import World` (O), `from omni.isaac.core import World` (X)
- 상세 마이그레이션 패턴은 `wiki/isaac_sim_api_patterns.md`를 참조하십시오.

### 1.2 MCP 통신 규격 (Isaac Sim & ROS2)
- **Isaac Sim (Port 8766)**: 컨테이너 내부의 MCP 익스텐션과 통신합니다. 
  - `uv run isaac_mcp/server.py`를 브릿지로 활용하십시오.
  - JSON-RPC 요청 시 반드시 **단일 행(Single-line)** JSON을 사용하여 Pydantic 검증 에러를 방지하십시오.
  - `tools/call` 전에는 반드시 `initialize` 절차가 선행되어야 합니다.
- **ROS2 (Port 9090)**: `rosbridge` 서버를 통해 통신합니다.
  - `uvx ros-mcp`를 사용하여 토픽 조회, 서비스 호출, 데이터 발행이 가능합니다.

### 1.3 직접 제어 (Direct Control)
- MCP 서버가 불안정할 경우, `docker exec`를 통해 컨테이너 내부에서 직접 `ros2` 명령어나 Isaac Sim Python 스크립트를 실행하는 것이 가장 확실한 대안입니다.

## 2. 권한 및 접근 (Access & Permissions)
- `datafactory`, `isaac-sim-mcp` 등은 외부 경로(`/home/codelab/Desktop/Project/`)를 가리키는 심볼릭 링크입니다. 
- 링크가 깨져 보일 경우 원본 경로로 직접 접근을 시도하십시오.

## 3. 스킬 확장 (Skill Augmentation)
- `external/robotics-agent-skills/`의 전문 지식을 `.claude/skills/`에 심링크하여 로봇 공학적 판단 능력을 즉각적으로 강화하십시오.

---
**이 지침은 Gemini가 로봇 하드웨어와 시뮬레이션을 안전하고 정밀하게 제어하기 위한 기반입니다.**
