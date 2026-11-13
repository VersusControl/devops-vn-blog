#!/usr/bin/env bash
# Wait up to 30 seconds for AWS Emulator to answer its health check.
set -euo pipefail

PORT="${EMULATOR_PORT:-9297}"
CA="$HOME/.aws/emulator/$PORT/ca.pem"

for _ in $(seq 30); do
  if [[ -f "$CA" ]] && curl -sf --cacert "$CA" "https://127.0.0.1:${PORT}/__admin/health" >/dev/null; then
    echo "AWS Emulator is ready on port $PORT"
    exit 0
  fi
  sleep 1
done

echo "AWS Emulator did not become healthy on port $PORT" >&2
exit 1
