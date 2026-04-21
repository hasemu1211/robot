# MCP 교훈

> DATAFACTORY에서 축적된 MCP(Model Context Protocol) 서버 연동 교훈.

## mcp 1.27.0 호환성 패치 (FastMCP breaking changes)

`isaac-sim-mcp` 업스트림은 `mcp<1.0` 기준. mcp>=1.27에서 FastMCP 생성자 시그니처 및 도구 리턴 타입 변경 → 패치 없이 서버 실행 시 `TypeError`.

```python
# 변경 전 (mcp < 1.0)
mcp = FastMCP(name="isaac-sim", description="Isaac Sim MCP server")

# 변경 후 (mcp >= 1.27)
mcp = FastMCP(name="isaac-sim")  # description 인수 삭제
```

도구 함수 리턴 타입:
```python
# 변경 전
return {"status": "ok", "payload": data}

# 변경 후
from mcp.types import TextContent
return [TextContent(type="text", text=json.dumps({"status": "ok", "payload": data}))]
```

업스트림 PR 대기 중. `mcp` 패키지 업그레이드 후 `isaac_mcp/server.py` 재확인.

## MCP 구성 우선순위 (Claude Code)

1. 프로젝트: `<project>/.mcp.json` (권장 — DATAFACTORY 방식)
2. 프로젝트: `<project>/.claude/settings.json` 의 `mcpServers`
3. 글로벌: `~/.claude/settings.json` 의 `mcpServers`

서브모듈/자식 프로젝트가 자체 `.mcp.json`을 가지면 해당 child에서만 해당 MCP 활성 → 디렉토리 기반 격리.

## MCP 연동 시 검증 순서

1. **먼저 연결 확인** — `get_scene_info()` (isaac-sim) 또는 `connect_to_robot()` (ros-mcp) 같은 "항상 먼저 호출" 도구로 연결 성공 확인.
2. 실패 시 서버 프로세스 확인: `ps aux | grep -E 'isaac_mcp|ros-mcp'`.
3. 포트 바인딩 확인: `netstat -tlnp | grep -E '8766|9090'`.
4. 로그 확인: `docker logs ${COMPOSE_PROJECT_NAME}_isaac_sim 2>&1 | tail -30 | grep MCP` (compose 실행 디렉토리 기준).

## 주요 MCP 서버 (distribution 포함)

### isaac-sim (포트 8766)
- 실행: `uv run ~/robot/vendor/isaac-sim-mcp/isaac_mcp/server.py`
- 도구: `get_scene_info`, `create_physics_scene`, `execute_script`, `create_robot`, `transform`
- Isaac Sim 내부에서 extension으로 TCP 리스너 (8766) 구동

### ros-mcp (포트 9090 = rosbridge)
- 실행: `uvx ros-mcp` (rosbridge 컨테이너가 별도로 9090 노출)
- 도구: `connect_to_robot`, `get_topics`, `subscribe_once`, `publish_once`, `call_service`
- rosbridge WebSocket 경유, Isaac Sim의 ROS2 bridge와 독립

## MCP extension 활성화 — Python API만 성공

Kit의 `[dependencies]` / `[settings.exts.*.enabled]` 선언은 모두 registry 조회를 동반 → 로컬 extension은 실패.

**권장 패턴:**
```python
# --exec enable_mcp.py
import omni.kit.app
manager = omni.kit.app.get_app().get_extension_manager()
if not manager.is_extension_enabled("isaac_sim_mcp_extension"):
    manager.set_extension_enabled("isaac_sim_mcp_extension", True)
```

자세한 내용은 `isaac_sim_api_patterns.md` 참조.

## create_robot lazy import 미패치 (알려진 이슈)

`extension.py` 상단 import는 4.5.0 API 경로로 패치됨. 하지만 일부 함수 내부의 lazy import는 미패치 상태:

```python
# create_robot() 내부 — 런타임 에러 유발
from omni.isaac.core.utils.prims import create_prim     # 미패치
from omni.isaac.core.utils.stage import add_reference_to_stage  # 미패치
```

**영향:** 서버 시작은 OK (lazy import는 함수 호출 시에만). `create_robot` 호출 시 `ModuleNotFoundError`.
**해결:** `create_robot` 사용 전에 extension.py 내 모든 lazy import도 `isaacsim.core.utils.*` 경로로 변경.

## MCP 서버 종료 및 재시작

```bash
# Claude Code 내부에서 등록된 MCP 목록
claude mcp list

# 특정 MCP 재등록
claude mcp remove isaac-sim
claude mcp add isaac-sim -- uv --directory ~/robot/vendor/isaac-sim-mcp run isaac_mcp/server.py

# 세션 재시작 필요 (Claude Code가 MCP를 세션 시작 시에만 로드)
```

## 다중 MCP 사용 시 분기

DATAFACTORY는 `isaac-sim`(Isaac 제어) + `ros-mcp`(ROS2 통신) 두 MCP를 프로젝트 레벨에서 격리. 각자 독립 프로세스/포트로 충돌 없음. 병렬 사용 가능.

향후 Docker MCP 등 추가 시에도 프로젝트 레벨 `.mcp.json`에만 선언하면 child 스코프 유지.

## 2026-04-21 — User-scope agent 파일은 세션 내 hot-load 불가

**Context**: 새 agent 정의를 `~/.claude/agents/*.md`에 mid-session으로 작성 후 `Task(subagent_type="<new-name>", ...)` 호출 시 → `Agent type '<new-name>' not found` 에러.

**확인된 동작:**
- 이용 가능 agent 목록은 **세션 시작 시 스캔된 상태로 frozen**. mid-session 추가 agent 파일은 미등록.
- `/reload-plugins`는 플러그인/스킬/훅 리로드는 수행하나 **user-scope `~/.claude/agents/*.md`는 포함 안 함**.
- 상위 project-scope(`~/robot/.claude/agents/`)도 동일할 가능성 높음 — 세션 시작 이전에 disk에 존재해야 함.

**실행 지침:**
- 새 agent 정의 추가/수정 시 **세션 재시작 필수**.
- CI-유사 자동화에서 agent 정의를 runtime으로 주입하는 접근은 작동 안 함 — bootstrap 시 저장소에 커밋된 상태로 세션 시작 필요.
- tmux pane 기반(`omc-teams`) 분리 메커니즘에는 이 제약 해당 없음 — 각 pane이 자체 세션이므로 pane 재시작이 "세션 재시작"과 등가.

**공식 문서 언급 부재** — 트러블슈팅 시 참조용으로 남김.
