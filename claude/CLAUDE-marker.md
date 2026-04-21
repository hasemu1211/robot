<!-- OMC:ROBOT:START -->
<!-- Injected by ~/robot/scripts/install.sh --step=claude. Do not edit by hand; re-run install.sh to update. -->
<!-- Placement contract: this block lives OUTSIDE (after) any existing <!-- OMC:START -->...<!-- OMC:END --> block. -->

## robot distribution

이 머신에는 [robot](https://github.com/hasemu1211/robot) 로봇 개발 환경 distribution이 설치되어 있습니다.

**진입점**
- parent: `cd ~/robot && claude` — 전체 distribution 관리, 새 child 부트스트랩
- child: `cd ~/robot/<child> && claude` — 프로젝트 작업 (2-Tier wiki 자동 로드)

**자주 쓰는 워크플로우**
- 새 child 생성: `~/robot/scripts/bootstrap-child.sh <name> --profile=isaac+ros2`
- 환경 검증: `~/robot/scripts/doctor.sh` (또는 `--json` CI용)
- dotfiles 병합: `~/robot/scripts/merge-dotfiles.sh`
- wiki 교훈 승격: `~/robot/scripts/promote.sh <child>/wiki/<file>.md`

**Distribution 자산 경계**
- `~/robot/vendor/isaac-sim-mcp/` — 패치된 Isaac Sim MCP (4.5 API + mcp 1.27 호환, submodule)
- `~/robot/templates/` — child 생성용 Docker/MCP/AGENTS 템플릿 (파라미터화)
- `~/robot/dotfiles/` — wezterm/tmux/xprofile (심링크 소스)
- `~/robot/external/robotics-agent-skills/` — 3rd-party 로봇 스킬 (submodule)
- `~/robot/claude/` — marker/settings seed/commands (install.sh가 이곳에서 ~/.claude/로 주입)

**공유 규칙**
- 모든 child에 공통적인 지식은 `~/robot/wiki/`로 승격 (`promote.sh` 사용)
- 프로젝트 고유 경로/수치/비밀은 `~/robot/<child>/` 스코프 유지
- NGC 토큰 등 비밀은 `.env.local` (gitignored) + shell env `--env-from-shell` 양쪽 지원

**관련 문서**
- `~/robot/wiki/agent_cookbook.md` — **(필독)** 실제 toolbox 카탈로그 + 레시피 + 관례
- `~/robot/docs/INSTALL.md` — install.sh 레이어별 상세
- `~/robot/docs/HOST_PREREQUISITES.md` — OS + Docker + NVIDIA 준비
- `~/robot/docs/MERGE_DOTFILES.md` — 기존 dotfiles와의 통합 절차
- `~/robot/README.md` — 3분 quickstart
<!-- OMC:ROBOT:END -->
