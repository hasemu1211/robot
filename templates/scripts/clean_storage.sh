#!/bin/bash
# Storage Pruning Script
# Isaac Sim 캐시 + Docker 레이어 정리

echo "=== Storage Pruning (${PROJECT_NAME}) ==="
echo "Before:"
df -h / | tail -1

# Docker 미사용 리소스 정리
echo ""
echo "[1/3] Docker 정리 중..."
docker container prune -f
docker volume prune -f
docker network prune -f

# Isaac Sim / Omniverse 캐시 정리
echo "[2/3] Isaac Sim 캐시 정리 중..."
rm -rf ~/.cache/ov/kit/* 2>/dev/null
rm -rf ~/.cache/ov/ComputeCache/* 2>/dev/null
rm -rf ~/.nvidia-omniverse/logs/* 2>/dev/null

# 임시 파일 정리
echo "[3/3] 임시 파일 정리 중..."
rm -rf /tmp/isaac_* 2>/dev/null

echo ""
echo "After:"
df -h / | tail -1
echo "=== Done ==="
