# notebooklm-py CLI 가이드

`notebooklm-py`는 Google NotebookLM 서비스를 CLI에서 자동화하고 대규모 문서를 관리하기 위한 도구입니다. 이 distribution에서는 로봇 관련 기술 스택(Isaac Sim, ROS2 등)의 방대한 문서를 에이전트가 빠르게 학습하거나 분석할 때 활용됩니다.

## 1. 설치

`scripts/install.sh`의 `cli` 레이어에서 자동으로 설치됩니다.
(`pip3 install --user 'notebooklm-py[browser]'`)

- **설치 건너뛰기**: `./scripts/install.sh --skip-notebooklm`
- **수동 설치**: `pip3 install --user 'notebooklm-py[browser]'`

설치 확인:
```bash
notebooklm --version
```

## 2. 인증 (OAuth)

첫 실행 시 Google 계정 인증이 필요합니다.

```bash
notebooklm login
```

- 브라우저가 열리면 Google 계정으로 로그인하고 권한을 승인합니다.
- 인증 토큰은 `~/.notebooklm/` 폴더에 안전하게 저장됩니다.
- 한 번 인증하면 이후에는 로그인 없이 사용 가능합니다.

## 3. 주요 워크플로우

### 3.1 새 노트북 생성 및 소스 업로드
로봇 프로젝트의 특정 모듈 소스 코드를 노트북에 업로드합니다.

```bash
# Isaac Sim API 패턴 문서를 소스로 새 노트북 생성
notebooklm notebook create "Isaac Sim Patterns" \
  --source wiki/isaac_sim_api_patterns.md
```

### 3.2 노트북 목록 및 상세 정보
```bash
notebooklm notebook list
notebooklm source list --notebook-id <ID>
```

### 3.3 자동화 요약 (Agent Recipe)
에이전트가 특정 코드베이스를 NotebookLM을 통해 분석하도록 지시할 때 유용합니다.

```bash
# 특정 디렉토리의 모든 마크다운 문서를 업로드하고 요약
notebooklm source upload-dir docs/ --notebook-id <ID>
```

## 4. 활용 팁

- **개인 자산 분리**: NotebookLM에 업로드된 데이터는 사용자의 Google 계정에 귀속됩니다.
- **Datafactory 통합**: `~/robot/datafactory`에 대규모 데이터셋(PDF, 소스코드)이 있는 경우, 이를 NotebookLM으로 인덱싱하여 Claude Code가 참고할 수 있게 할 수 있습니다.

## 5. 트러블슈팅

- **브라우저 실행 안 됨**: SSH 세션인 경우 브라우저 실행이 불가능할 수 있습니다. 로컬 터미널에서 `notebooklm login`을 수행한 뒤 `~/.notebooklm/` 폴더를 복사하거나, `X11 forwarding`을 사용하세요.
- **인증 만료**: `notebooklm login`을 다시 실행하여 토큰을 갱신하세요.
