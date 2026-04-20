# ROS2 Bridge 패턴

> Isaac Sim과 ROS2 Humble 간 통신 설정 및 rosbridge 컨테이너 교훈.

## ROS2 Humble 내장 라이브러리 활성화 (Isaac Sim 컨테이너 내부)

Isaac Sim 컨테이너에는 ROS2 Humble 라이브러리가 내장되어 있음. 사용하려면 환경변수로 활성화:

```yaml
environment:
  - RMW_IMPLEMENTATION=rmw_fastrtps_cpp
  - LD_LIBRARY_PATH=/isaac-sim/exts/isaacsim.ros2.bridge/humble/lib
```

이 두 줄이 없으면 Isaac Sim 내 ROS2 bridge extension이 로드 실패.

## DDS 자동 발견 (network_mode: host)

```yaml
services:
  isaac-sim-streaming:
    network_mode: host
    ipc: host
  ros2:
    network_mode: host
    ipc: host
```

`network_mode: host` + `ipc: host` 조합으로:
- DDS(Data Distribution Service) peer discovery 자동
- 컨테이너 간 공유 메모리 통신 → 복사 오버헤드 제거
- 별도 포트 매핑 불필요

## rosbridge Docker 이미지 (Dockerfile.ros2)

rosbridge_server를 사용해 Claude Code ↔ ROS2 간 WebSocket 브릿지:

```dockerfile
FROM ros:humble

RUN apt-get update && apt-get install -y \
    ros-humble-rosbridge-server \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 9090

CMD ["bash", "-c", "source /opt/ros/humble/setup.bash && ros2 launch rosbridge_server rosbridge_websocket_launch.xml"]
```

포트 9090 = rosbridge WebSocket. Claude Code `ros-mcp`가 이 포트로 연결.

## docker-compose profile 분리 (Phase 4 전까지 ros2 선택적)

```yaml
ros2:
  profiles: ["ros2"]     # Phase 4 전까지 불필요
  ...
```

실행:
```bash
# Isaac Sim만
docker compose --profile streaming up

# ROS2도 함께
docker compose --profile ros2 up -d ros2
```

## ROS_DISTRO 환경변수 전파

```yaml
environment:
  - ROS_DISTRO=humble
```

일부 Isaac Sim 내부 스크립트가 `$ROS_DISTRO`를 참조하므로 명시적 export 권장.

## 토픽 리스트 확인 (smoke test)

```bash
docker exec datafactory_ros2 bash -c "source /opt/ros/humble/setup.bash && ros2 topic list"
```

기본 토픽 (rosbridge만 실행된 상태):
- `/rosout`
- `/parameter_events`

Isaac Sim에서 ROS2 bridge extension 활성화 시 카메라/IMU 등 센서 토픽이 자동 publish.

## 시공간 동기화 (Phase 4 대상)

Isaac Sim 시뮬레이션 시간 vs ROS2 시계 동기화는 시공간 Δt 측정의 핵심. `/clock` 토픽 publish 활성화:

```python
# Isaac Sim 내부 (execute_script)
from omni.isaac.ros2_bridge import _ros2_bridge
# use_sim_time: true 설정 후 /clock publish
```

## 공통 실패 패턴

- **DDS discovery 실패**: `network_mode: host` 누락. 브리지 모드에서는 수동 FastDDS discovery server 필요.
- **ROS_DISTRO not found 경고**: Isaac Sim 컨테이너 내부 경고. ROS2 bridge 미사용 시 무시 가능.
- **rosbridge 9090 포트 충돌**: 호스트에서 다른 프로세스가 점유 시 `lsof -i :9090`로 확인.
