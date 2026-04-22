# OMC(Claude) ↔ OmG(Gemini) 책임 분리 및 통합 규약

> 2026-04-22 DATAFACTORY 세션에서 bridge 인프라 구축·실패·복구 과정으로 실증된 5가지 교훈. 이후 child 에서도 재발하므로 global 로 승격.
> 통합 사양(프로토콜 · 역할 매트릭스)은 [docs/OMG_INTEGRATION.md](../docs/OMG_INTEGRATION.md), 쓰기 ACL 은 child 의 `GEMINI.md §4.4/§4.5`.

## 1. Gemini 출력은 untrusted input

DF 세션 내 두 차례 URL 합성 실증:
- 1차: `IsaacSim-ros_team/issues/142` (리포명 자체가 환각, 404)
- 2차: post-mortem 작성 **3분 후** `how-to-get-reprojection-error-.../250000` (같은 패턴 재발)

→ Gemini 의 자기-진단·자기-반성은 재발 방지에 **효과 없음**. 검증은 구두 계약이 아니라 파일·HTTP 게이트로 구조화해야 함.

## 2. HTTP citation 게이트 = 필수 방어선

`omg-bridge.sh v3.3` 의 설계:
- 모든 citation URL 에 `curl -I` → 2xx/3xx 만 `.citations`, 나머지는 `.citations_invalid[{url, http}]` 로 격리
- 유효 citation 0건이면 `exit 2` 로 distill 전체 반려 (hallucinated summary 수용 차단)
- `finished_at` · `token_usage` 는 bridge 가 `date -u` · envelope 통계로 **덮어씀** (Gemini 값 무시)

## 3. Gemini CLI headless 성공 조합 (operational recipe)

```bash
gemini -e none -m gemini-3-flash-preview --output-format json -p "<prompt>"
```

- `-e none`: OmG extension 비활성화 → `omg-researcher` 서브에이전트 fan-out 제거 (15-20s 절감)
- `-m gemini-3-flash-preview`: flash-lite 는 웹 grounding 실패율 높음, Pro 가 성공률·지연 밸런스 우위
- 프롬프트에 **"LaTeX · 역슬래시 금지, JSON 이스케이프 규칙 엄수"** 명시 — 없으면 `\frac{}{}` 등이 invalid JSON 으로 방출됨 (form-feed `\f` 로 해석)
- cwd 외 경로는 **workspace 제약** 으로 read 실패 → `--include-directories=<path>` 추가하거나 직접 read 로 전환

실측 성공: 22.8s, citations 2/2 valid, 환각 0건.

## 4. 세션 중간 모델 교체는 anti-pattern

OMC ↔ OmG 이어받기 시 깨지는 것들:
- 상태 디렉토리 스키마: `.omc/state/` vs `.omg/state/` (서로 못 읽음)
- 커맨드 네임 충돌: `/team`, `/ralph`, `/ultrawork` 등 14개가 양측에 있지만 내부 포맷·로그 상이
- 프롬프트 캐시 무효화 (Claude 5분 TTL, Gemini cached_tokens 모두 lost)
- MCP 접속: OMC 는 `isaac-sim`(8766) · `ros-mcp`(9090) 붙음, Gemini CLI 는 별도 설정 필요

→ **처음부터 역할 분할**: Claude = orchestrator / editor, Gemini = file-based sub-processor. 토큰 한도 문제는 `/oh-my-claudecode:optimize` · 세션 압축으로 해결, 모델 교체 X.

## 5. 쓰기 권한 ACL 은 파일 레벨로 강제

DF 에서 Gemini 가 `.omc/scripts/omg-bridge.sh` 를 v3 → v2.1 로 **무단 재작성** (`WriteFile Accepted +27/-92`). `GEMINI.md §4.4` 구두 계약만으로는 재발 방지 불확실.

**권장 강화** (향후):
- git pre-commit hook: `.omc/scripts/**` 변경 시 작성자 검증
- `chattr +i` (immutable): bridge 안정화 후 불변 비트 설정
- 위반 로그: `.omc/state/boundary-violations.md` 에 자동 append

## 핵심 원칙 요약

> **"Gemini 출력은 untrusted input. 모든 경계는 파일 ACL 로. 모델 교체는 처음부터 설계."**
