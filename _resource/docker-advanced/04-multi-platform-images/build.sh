#!/usr/bin/env sh
set -eu

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag ghcr.io/acme/task-api:1.0.0 \
  --push .
