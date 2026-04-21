---
type: lesson
title: Docker / docker-compose 교훈
date: 2026-04-17
---

# Docker / docker-compose 교훈

## docker-compose profiles로 GUI/Headless 분리
```yaml
# GUI 모드
isaac-sim-gui:
  profiles: ["gui"]
  command: ["/isaac-sim/isaac-sim.sh"]

# Headless 모드
isaac-sim-headless:
  profiles: ["headless"]
  command: ["/isaac-sim/python.sh", "/data/scripts/generate.py"]
```
- 실행: `docker compose --profile gui up`
- ROS2는 profile 없이 항상 포함

## 컨테이너 이름 충돌 처리
- 같은 `container_name` 재사용 시 충돌 에러
- `docker stop <이름> && docker rm <이름>` 후 재실행

## Isaac Sim ↔ ROS2 통신
- `network_mode: host` + `ipc: host` → DDS 자동 발견
- 별도 포트 매핑 불필요

## 스토리지 관리
- Isaac Sim 셰이더 캐시: `~/.cache/ov/` (정기 삭제 필요)
- `scripts/clean_storage.sh` 주기적으로 실행
