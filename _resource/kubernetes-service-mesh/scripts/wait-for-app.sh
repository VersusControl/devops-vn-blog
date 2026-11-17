#!/usr/bin/env bash
# Wait for every Deployment in a namespace, one at a time, so a failure names
# the Deployment that is stuck instead of reporting all of them.
#   ./scripts/wait-for-app.sh [namespace] [timeout]
set -euo pipefail
ns="${1:-bookstore}"
timeout="${2:-600s}"

for d in $(kubectl -n "$ns" get deploy -o name); do
  if ! kubectl -n "$ns" rollout status "$d" --timeout="$timeout"; then
    echo >&2
    echo "$d is not ready. Its Pods:" >&2
    kubectl -n "$ns" get pods -l "app=$(kubectl -n "$ns" get "$d" -o jsonpath='{.metadata.labels.app}')" >&2
    echo "Look at the events: kubectl -n $ns describe ${d/deployment.apps/deploy}" >&2
    exit 1
  fi
done
