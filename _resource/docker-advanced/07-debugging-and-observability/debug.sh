#!/usr/bin/env sh
set -eu

container_name=${1:?Usage: debug.sh CONTAINER}
docker logs --tail 200 "$container_name"
docker inspect "$container_name" --format '{{.State.ExitCode}} {{.State.OOMKilled}}'
docker stats --no-stream "$container_name"
