#!/bin/sh
# 컨테이너 내부에서 직접 심링크 생성 (호스트 심링크 의존 X)
ln -sfn /opt/isaac-sim-mcp/isaac.sim.mcp_extension /isaac-sim/exts/isaac_sim_mcp_extension

/isaac-sim/license.sh && /isaac-sim/privacy.sh && \
exec /isaac-sim/kit/kit \
  /opt/kit/isaacsim.streaming.mcp.kit \
  --ext-folder /isaac-sim/exts \
  --ext-folder /isaac-sim/apps \
  --exec /opt/kit/enable_mcp.py \
  --merge-config="/isaac-sim/config/open_endpoint.toml" \
  --/persistent/isaac/asset_root/default="$OMNI_SERVER" \
  --allow-root \
  --no-window
