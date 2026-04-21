# Verified Machines

이 distribution이 실제로 작동 확인된 환경 목록. 신규 환경 기여 환영 (PR).

각 엔트리:
- 설치 날짜 (UTC)
- OS + 하드웨어 요약
- `doctor.sh --json` 전체 출력 경로 또는 서머리
- 알려진 issues / 특이 사항

## 포맷

```markdown
### <YYYY-MM-DD> · <환경 서머리>

- OS: Ubuntu 22.04 (jammy)
- GPU: <NVIDIA 모델> (compute capability <sm>, VRAM <GB>)
- CPU: <모델> · RAM: <GB>
- Docker: <version> · NVIDIA Container Toolkit: <version>
- doctor.sh 결과: <N green, N warn, N fail> (총 <N> 체크)
- install.sh 전체 소요: <min>
- Notes: <특이사항>
```

---

## 검증 기록

### 2026-04-21 · 초기 distribution landing (개발자 머신)

- OS: Ubuntu 22.04 (jammy)
- GPU: RTX 5060 (compute capability sm_120, VRAM 8GB)
- CPU: Intel i5-14400F · RAM: 16GB
- Docker: 24.x · NVIDIA Container Toolkit: 1.14+
- 상태: **in-progress** — Phase H 자동 검증 PASS, Phase H-3b (VM `docker compose up` e2e) 보류 (GPU 리소스 충돌 방지 + Phase B fork 필요)
- Notes:
  - iray photoreal GPU 미지원 경고 — Blackwell 특이, RTX Renderer로 대체 (원본 datafactory 교훈 유지)
  - `~/robot/isaac-sim-mcp` 심링크 유지 (vendor/ 로 retarget 예정, Phase B fork 후)
  - AC-4 portability grep: 0 히트 (code/templates/scripts 스코프)
  - `doctor.sh --layer=datafactory` 이 compose config 성공 → 기존 datafactory workflow 계속 작동 (AC-6)
  - rtk 0.37.2 설치 + Claude Code 훅 등록 — install.sh cli 레이어에 포함

---

## Fresh VM e2e 검증 템플릿 (Phase H-3b)

아래는 **새 Ubuntu 22.04 VM에서 수행한 e2e 체크리스트** — 수동 실행 후 결과를 위 형식으로 추가.

```bash
# 가상 머신 요구: Ubuntu 22.04, NVIDIA GPU (passthrough), 80GB+ 디스크
# 1. 기본 셋업
sudo apt update && sudo apt install -y git curl
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
npm install -g @anthropic-ai/claude-code

# 2. clone
git clone --recurse-submodules https://github.com/hasemu1211/robot ~/robot
cd ~/robot

# 3. NGC 토큰
export NGC_API_KEY=xxx

# 4. install
./scripts/install.sh --yes --env-from-shell | tee install-vm.log

# 5. doctor baseline
./scripts/doctor.sh --json > doctor-vm.json
jq -e '.summary.fail == 0' doctor-vm.json

# 6. bootstrap-child smoke
./scripts/bootstrap-child.sh testchild --profile=isaac+ros2
cd testchild
docker compose --profile streaming up -d
sleep 60
# Claude Code 세션 시작 → `get_scene_info()` 호출 성공 확인

# 7. rosbridge
docker compose --profile ros2 up -d ros2
# Claude Code → `connect_to_robot(port=9090)` 성공 확인

# 8. cleanup
docker compose down -v
cd .. && rm -rf testchild
```

결과를 이 파일에 기록 + `install-vm.log` / `doctor-vm.json` 아티팩트 첨부 (PR).
