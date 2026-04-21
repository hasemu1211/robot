# Developer & Maintainer Guide (업데이트 및 확장 매뉴얼)

이 문서는 `robot` 배포판에 새로운 도구, MCP 서버, 또는 스킬을 추가하고 유지보수하는 방법을 설명합니다. 이 배포판은 **"Source (repo) → Target (~/.local, ~/.claude)"** 구조를 따르므로, 원본 소스를 수정하고 설치 프로그램을 통해 배포하는 흐름을 이해해야 합니다.

## 1. 새로운 Skill (Command) 추가하기

Claude Code에서 사용할 커스텀 명령어(`.md` 파일)를 추가하는 방법입니다.

1.  **파일 작성**: `claude/commands/` 폴더 내에 새로운 마크다운 스킬 파일을 작성합니다 (예: `my-new-skill.md`).
2.  **배포**: `./scripts/install.sh --step=claude`를 실행합니다.
    - `install.sh`의 `link_commands` 함수가 자동으로 `~/.claude/commands/`에 심링크를 생성합니다.
3.  **확인**: `claude` 실행 후 `/`를 입력하여 목록에 새 스킬이 나타나는지 확인합니다.

## 2. 새로운 MCP 서버 추가하기

MCP 서버는 적용 범위에 따라 두 가지 위치 중 선택합니다.

### A. 모든 Child 프로젝트에 기본 포함할 때 (권장)
사용자가 `bootstrap-child.sh`로 새 프로젝트를 만들 때마다 자동으로 포함되게 하려면:
1.  `templates/.mcp.json.tmpl` 파일을 수정합니다.
2.  `mcpServers` 섹션에 새로운 서버 설정을 추가합니다.
3.  `${ROBOT_ROOT}` 변수를 사용하여 배포판 내의 경로를 참조할 수 있습니다.

### B. 전역(Global) 사용자 설정에 추가할 때
어떤 디렉토리에서든 항상 활성화되게 하려면:
1.  `claude/settings-seed.json` 파일을 수정합니다.
2.  `mcpServers` 섹션(필요시 신설)에 설정을 추가합니다.
3.  `./scripts/install.sh --step=claude`를 실행하여 사용자의 `~/.claude/settings.json`과 병합합니다.

## 3. 새로운 CLI 도구 및 의존성 추가하기

1.  **설치 로직 추가**: `scripts/install.sh`의 `cli` 레이어나 `host` 레이어에 설치 명령어를 추가합니다.
2.  **검증 로직 추가**: `scripts/doctor.sh`의 해당 레이어에 `record_check` 로직을 추가하여 설치 성공 여부를 확인합니다.
3.  **문서화**: `docs/INSTALL.md` 및 `README.md`에 새로운 도구가 추가되었음을 명시합니다.

## 4. 에이전트 오리엔테이션 업데이트 (필수)

새로운 도구나 MCP가 추가되면 에이전트(Claude)가 이를 인지할 수 있도록 정보를 제공해야 합니다.

1.  **Agent Cookbook 업데이트**: `wiki/agent_cookbook.md`의 도구 목록과 레시피 섹션에 새 도구 활용법을 추가합니다.
2.  **포인터 확인**: `claude/CLAUDE-marker.md`나 `AGENTS.md` 등 세션 시작 시 에이전트가 읽는 파일에 관련 링크가 잘 걸려 있는지 확인합니다.

## 5. 보안 및 클린 배포 가이드

- **절대 경로 금지**: 스크립트나 설정 파일에서 `/home/user` 같은 절대 경로를 사용하지 마세요. 대신 `$HOME` 또는 `${ROBOT_ROOT}`를 사용하세요. 
    *   **MCP 설정 예**: `sh -c 'node "$HOME/.claude/..."'` 방식을 사용하여 사용자마다 다른 홈 디렉토리를 유연하게 처리할 수 있습니다.
- **Secrets 관리**: 새로운 API Key가 필요하다면 `.env.template`에 주석을 달고, `install.sh`에서 `.env.local`로 유도하는 로직을 추가하세요.
- **Idempotency (멱등성)**: 스크립트는 여러 번 실행해도 안전해야 합니다. 이미 설정이 되어 있다면 `log_skip`으로 넘어가도록 설계하세요.

---

이 가이드를 준수함으로써 `robot` 배포판의 일관성을 유지하고, 모든 사용자에게 고품질의 개발 환경을 제공할 수 있습니다.
