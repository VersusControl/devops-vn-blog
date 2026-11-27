#!/usr/bin/env bash
# Run an Envoy config on your laptop with the same Envoy minor version as the proxy (1.40),
# before you send it to AWS. Usage: scripts/run-local.sh envoy/config-v2.yaml
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${1:-envoy/config.yaml}"
IMAGE="envoyproxy/envoy:v1.40-latest"

# The same check ELB for Envoy runs before it starts Envoy.
docker run --rm -v "$PWD/envoy:/envoy:ro" --entrypoint envoy "$IMAGE" \
  --mode validate -c "/$CONFIG" | tail -1

# Listener port 80 in the container -> localhost:18080. Stop with Ctrl+C.
echo "Serving $CONFIG on http://localhost:18080/"
docker run --rm -p 18080:80 -v "$PWD/envoy:/envoy:ro" --entrypoint envoy "$IMAGE" -c "/$CONFIG"
