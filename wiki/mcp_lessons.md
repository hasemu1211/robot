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
4. 로그 확인: `docker logs datafactory_isaac_sim 2>&1 | tail -30 | grep MCP`.

## 주요 MCP 서버 (DATAFACTORY 검증됨)

### isaac-sim (포트 8766)
- 실행: `uv run ~/Desktop/Project/isaac-sim-mcp/isaac_mcp/server.py`
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
claude mcp add isaac-sim -- uv --directory ~/Desktop/Project/isaac-sim-mcp run isaac_mcp/server.py

# 세션 재시작 필요 (Claude Code가 MCP를 세션 시작 시에만 로드)
```

## 다중 MCP 사용 시 분기

DATAFACTORY는 `isaac-sim`(Isaac 제어) + `ros-mcp`(ROS2 통신) 두 MCP를 프로젝트 레벨에서 격리. 각자 독립 프로세스/포트로 충돌 없음. 병렬 사용 가능.

향후 Docker MCP 등 추가 시에도 프로젝트 레벨 `.mcp.json`에만 선언하면 child 스코프 유지.

## 2026-04-21 — Agent frontmatter scope enforcement probe (A-0)

**Plan:** `~/robot/datafactory/.omc/plans/robot-omc-role-scoped-distillation-plan.md` Phase A-0.
**Decision (AM-6):** Schema **γ (`disallowedTools:`)** 단독 채택 (β+γ 기각).

### 실측 결과: 유저 스코프 agent는 **세션 내 hot-load 불가**

- 세션 3 중 `~/.claude/agents/probe-scope-gamma.md`를 생성하고 즉시 `Agent(subagent_type="probe-scope-gamma", ...)` 호출 → `Agent type 'probe-scope-gamma' not found` 에러.
- 이용 가능 목록에는 기존 OMC + 내장 agent 25개만 등록. 새로 쓴 파일은 미등록.
- `/reload-plugins`는 플러그인/스킬/훅은 리로드하나 **유저 스코프 `~/.claude/agents/*.md`는 세션 시작 시에만 스캔**.

### 함의

1. **AM-2 가정 부분 수정**: 유저 스코프는 "발견된다"가 맞지만, **"mid-session 추가는 반영 안 됨"**. Phase A-1에서 agent 파일을 작성해도 동일 세션에서 Phase B(스코프 위반 probe)를 실행 **불가능**. Phase B는 반드시 새 세션에서 수행.
2. **γ 선언적 차단 empirical 확인은 Phase B-2 Case A/C(servant invocation)에서 일어남**, A-0는 아님. A-0의 static evidence(OMC shipped agent 8/8 = γ)가 선언적 차단에 대한 **간접 증거**로 유지.
3. **상위 경로(`~/robot/.claude/agents/`)도 동일**할 것으로 추정 — 모든 agent 정의는 세션 시작 전 disk에 존재해야 함.

### 실행 지침

- Phase A에서 agent 정의 작성 + atomic commit → 세션 종료 → 새 세션(`cd ~/robot/datafactory && claude`)에서 Phase B 실행.
- 유저가 agent 정의 수정 시 **매번 세션 재시작 필요**하다고 `omc_robot_profile.md` §Troubleshooting에 경고 추가.

### Promotion worthiness
**Promotion-worthy**: 이 동작은 공식 문서에 명시 안 됨 + 여러 session-2 가정에 영향. 이후 `wiki/` → project level로 승격 가치 있음.
