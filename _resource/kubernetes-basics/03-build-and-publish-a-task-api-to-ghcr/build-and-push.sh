#!/usr/bin/env sh
set -eu

: "${GHCR_OWNER:?Set GHCR_OWNER to your GitHub user or organization.}"
: "${GHCR_TOKEN:?Set GHCR_TOKEN to a GitHub token with write:packages.}"

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
task_api_dir="${script_dir}/../task-api"
image="ghcr.io/${GHCR_OWNER}/task-api:0.1.0"

docker build -t task-api:0.1.0 "${task_api_dir}"
docker tag task-api:0.1.0 "${image}"
printf '%s' "${GHCR_TOKEN}" | docker login ghcr.io -u "${GHCR_OWNER}" --password-stdin
docker push "${image}"